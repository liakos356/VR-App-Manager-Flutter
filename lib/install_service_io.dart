import 'dart:io';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class InstallService {
  static const platform = MethodChannel('com.vr.appmanager/install');

  static Future<void> installAppLocally({
    required String appId,
    required String apkPath,
    required String obbDir,
    required Function(String) onProgress,
    Function(double)? onDownloadProgress,
  }) async {
    // Request necessary permissions for Android 10+ devices (like Pico 4)
    if (Platform.isAndroid) {
      onProgress('Requesting permissions...');
      await Permission.requestInstallPackages.request();

      if (!await Permission.manageExternalStorage.isGranted) {
        onProgress('Please grant All Files Access in Settings if prompted...');
        await Permission.manageExternalStorage.request();
      }

      if (!await Permission.storage.isGranted) {
        await Permission.storage.request();
      }
    }

    Smb2Pool? pool;
    try {
      onProgress('Connecting to SMB...');
      pool = await Smb2Pool.connect(
        host: '100.95.32.89',
        share: 'ssd_internal',
        user: 'liakos',
        password: 'stella.elias.240922',
        workers: 1,
      );

      final dlPath = '/sdcard/Download/$appId.apk';
      final apkFile = File(dlPath);

      onProgress('Checking SMB for APK...');

      bool apkFound = false;

      Future<bool> downloadWithProgress(
        String remotePath,
        File localFile,
      ) async {
        try {
          final exists = await pool!.exists(remotePath);
          if (!exists) return false;

          final size = await pool.fileSize(remotePath);
          onProgress('Downloading ${localFile.path.split('/').last} ($size bytes)...');
          
          if (size == 0) {
             onProgress('Error: Remote file size is 0 bytes.');
             return false;
          }

          final stream = pool.streamFile(
            remotePath,
            chunkSize: 1024 * 1024 * 2,
          );

          int downloaded = 0;
          final sink = localFile.openWrite();
          try {
            await for (var chunk in stream) {
              sink.add(chunk);
              downloaded += chunk.length;
              if (size > 0 && onDownloadProgress != null) {
                onDownloadProgress(downloaded / size);
              }
            }
          } finally {
            await sink.flush();
            await sink.close();
          }
          
          final finalSize = await localFile.length();
          onProgress('Downloaded $finalSize bytes.');
          
          if (size > 0 && finalSize < size) {
            onProgress('Download incomplete for ${localFile.path}');
            return false;
          }
          
          return true;
        } catch (e) {
          onProgress('Download stream failed: $e');
          return false;
        }
      }

      // Extract the relative path without the mount prefix since SMB starts at share root
      // E.g., /mnt/sda/downloads/... -> downloads/...
      String relativeApkPath = apkPath;
      if (relativeApkPath.startsWith('/mnt/sda/')) {
        relativeApkPath = relativeApkPath.substring('/mnt/sda/'.length);
      } else if (relativeApkPath.startsWith('/')) {
        relativeApkPath = relativeApkPath.substring(1);
      }
      if (relativeApkPath.startsWith('ssd_internal/')) {
        relativeApkPath = relativeApkPath.substring('ssd_internal/'.length);
      }

      // Ensure we use backslashes for SMB paths just in case
      relativeApkPath = relativeApkPath.replaceAll('/', '\\');

      onProgress('Trying direct path: $relativeApkPath');

      // Try direct apk first using path from DB
      if (relativeApkPath.isNotEmpty) {
        try {
          onProgress('Downloading APK: $relativeApkPath...');
          apkFound = await downloadWithProgress(relativeApkPath, apkFile);
        } catch (e) {
          onProgress('Direct path failed: $e');
        }
      }

      if (!apkFound) {
        onProgress(
          'Checking alternate path downloads/pico4/apps/$appId.apk...',
        );
        try {
          onProgress('Downloading APK...');
          apkFound = await downloadWithProgress(
            'downloads\\pico4\\apps\\$appId.apk',
            apkFile,
          );
        } catch (e) {
          // Ignore if alternate path not found
        }
      }

      if (!apkFound) {
        // Try looking in a folder: downloads/pico4/apps/[appId]/
        onProgress('Checking folder downloads/pico4/apps/$appId...');
        final folder = 'downloads\\pico4\\apps\\$appId';

        List<dynamic> files = [];
        try {
          files = await pool.listDirectory(folder);
          onProgress('Found folder $folder, contains ${files.length} items');
        } catch (e) {
          onProgress('Folder $folder not found or error: $e');
        }

        for (var f in files) {
          onProgress('Inspecting ${f.name} in folder...');
          if (f.name.endsWith('.apk')) {
            onProgress('Downloading APK: ${f.name}...');
            apkFound = await downloadWithProgress(
              '$folder\\${f.name}',
              apkFile,
            );
            if (apkFound) break;
          }
        }

        if (!apkFound) {
          throw Exception('No APK found for $appId on SMB');
        }
      }

      // Also look for OBB files
      onProgress('Checking OBB...');

      // Try reading from the specified obb directory in DB if available
      String relativeObbPath = obbDir;
      if (relativeObbPath.startsWith('/mnt/sda/')) {
        relativeObbPath = relativeObbPath.substring('/mnt/sda/'.length);
      } else if (relativeObbPath.startsWith('/')) {
        relativeObbPath = relativeObbPath.substring(1);
      }

      relativeObbPath = relativeObbPath.replaceAll('/', '\\');

      String obbFolderName = appId;
      if (relativeObbPath.isNotEmpty) {
        final segments = relativeObbPath.split('\\');
        if (segments.isNotEmpty && segments.last.isNotEmpty) {
          obbFolderName = segments.last;
        }
      }
      final localObbDir = Directory('/sdcard/Android/obb/$obbFolderName');

      List<dynamic> obbFiles = [];
      try {
        if (relativeObbPath.isNotEmpty) {
          onProgress('Checking OBB in $relativeObbPath...');
          obbFiles = await pool.listDirectory(relativeObbPath);
        } else {
          onProgress('Checking OBB in downloads\\pico4\\apps\\$appId...');
          obbFiles = await pool.listDirectory('downloads\\pico4\\apps\\$appId');
        }
      } catch (e) {
        onProgress('OBB directory not found: $e');
      }

      final folderToUse = relativeObbPath.isNotEmpty
          ? relativeObbPath
          : 'downloads\\pico4\\apps\\$appId';

      for (var f in obbFiles) {
        if (f.name.endsWith('.obb')) {
          onProgress('Downloading OBB ${f.name}...');

          if (!await localObbDir.exists()) {
            try {
              await localObbDir.create(recursive: true);
            } catch (e) {
              throw Exception(
                'Permission denied for ${localObbDir.path}. '
                'Go to Pico Settings -> Apps -> VR App Manager -> Permissions and enable "All Files Access".\n\n'
                'Details: $e',
              );
            }
          }
          final localObbFile = File('${localObbDir.path}/${f.name}');
          try {
            final success = await downloadWithProgress(
              '$folderToUse\\${f.name}',
              localObbFile,
            );
            if (!success) {
              throw Exception('OBB download stream failed for ${f.name}');
            }
          } catch (e) {
            throw Exception(
              'Failed to write OBB file. Please ensure storage permissions are granted. Error: $e',
            );
          }
        }
      }

      onProgress('Triggering Native Install...');
      final result = await platform.invokeMethod('installApk', {
        'apkPath': apkFile.path,
      });
      if (result == true) {
        onProgress('Installation Started!');
      } else {
        throw Exception(
            'Installation Intent Failed: The APK might be corrupt, incompletely downloaded, or its CPU architecture (e.g. arm64) is not supported by this device (e.g. x86_64 Emulator).');
      }
    } catch (e) {
      throw Exception('Install Error: $e');
    } finally {
      await pool?.disconnect();
    }
  }
}
