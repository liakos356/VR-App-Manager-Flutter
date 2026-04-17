import 'dart:io';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

// ── SMB configuration ─────────────────────────────────────────────────────
// TODO: Move these to a build-time config or secure storage before releasing.
const String _kSmbHost = '100.95.32.89';
const String _kSmbShare = 'ssd_internal';
const String _kSmbUser = 'liakos';
const String _kSmbPassword = 'stella.elias.240922';

class InstallService {
  static const platform = MethodChannel('com.vr.appmanager/install');

  static Future<void> installAppLocally({
    required String appId,
    required String apkPath,
    required String obbDir,
    required Function(String) onProgress,
    Function(double)? onDownloadProgress,
    bool Function()? isCancelled,
  }) async {
    // Request necessary permissions for Android 10+ devices
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
      debugPrint('[InstallService] Connecting to SMB for $appId...');
      onProgress('Connecting to SMB...');

      // Allow UI to repaint
      await Future.delayed(const Duration(milliseconds: 50));

      pool = await Smb2Pool.connect(
        host: _kSmbHost,
        share: _kSmbShare,
        user: _kSmbUser,
        password: _kSmbPassword,
        workers: 1,
      );

      final dlPath = '/sdcard/Download/$appId.apk';
      final apkFile = File(dlPath);
      debugPrint('[InstallService] DL path set to ${apkFile.path}');

      final dl = _SmbDownloader(
        pool: pool,
        onProgress: onProgress,
        onDownloadProgress: onDownloadProgress,
        isCancelled: isCancelled,
      );

      // 1. Resolve APK size and path
      String apkRemotePathToDownload = '';
      int apkSize = 0;

      String relativeApkPath = apkPath;
      if (relativeApkPath.startsWith('/mnt/sda/')) {
        relativeApkPath = relativeApkPath.substring('/mnt/sda/'.length);
      } else if (relativeApkPath.startsWith('/')) {
        relativeApkPath = relativeApkPath.substring(1);
      }
      if (relativeApkPath.startsWith('ssd_internal/')) {
        relativeApkPath = relativeApkPath.substring('ssd_internal/'.length);
      }
      relativeApkPath = relativeApkPath.replaceAll('/', '\\');

      onProgress('Locating APK...');
      if (relativeApkPath.isNotEmpty) {
        apkSize = await dl.getRemoteSize(relativeApkPath);
        if (apkSize > 0) apkRemotePathToDownload = relativeApkPath;
      }

      if (apkSize == 0 || apkRemotePathToDownload.isEmpty) {
        final altApkPath = 'downloads\\pico4\\apps\\$appId.apk';
        apkSize = await dl.getRemoteSize(altApkPath);
        if (apkSize > 0) apkRemotePathToDownload = altApkPath;
      }

      if (apkSize == 0 || apkRemotePathToDownload.isEmpty) {
        final folder = 'downloads\\pico4\\apps\\$appId';
        try {
          List<dynamic> files = await pool.listDirectory(folder);
          for (var f in files) {
            String name = f.name.toString();
            if (name.endsWith('.apk')) {
              final checkPath = '$folder\\$name';
              apkSize = await dl.getRemoteSize(checkPath);
              if (apkSize > 0) {
                apkRemotePathToDownload = checkPath;
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('[InstallService] Error listing dir $folder: $e');
        }
      }

      if (apkSize == 0 || apkRemotePathToDownload.isEmpty) {
        throw Exception('No APK found for $appId on SMB');
      }

      debugPrint(
        '[InstallService] Resolved APK: $apkRemotePathToDownload ($apkSize bytes)',
      );

      // 2. Resolve OBB sizes and paths
      onProgress('Locating OBBs...');
      String relativeObbPath = obbDir;
      if (relativeObbPath.startsWith('/mnt/sda/')) {
        relativeObbPath = relativeObbPath.substring('/mnt/sda/'.length);
      } else if (relativeObbPath.startsWith('/')) {
        relativeObbPath = relativeObbPath.substring(1);
      }
      if (relativeObbPath.startsWith('ssd_internal/')) {
        relativeObbPath = relativeObbPath.substring('ssd_internal/'.length);
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
      List<Map<String, dynamic>> obbFilesToDownload = [];
      final folderToUseObb = relativeObbPath.isNotEmpty
          ? relativeObbPath
          : 'downloads\\pico4\\apps\\$appId';

      try {
        final obbList = await pool.listDirectory(folderToUseObb);
        for (var f in obbList) {
          String name = f.name.toString();
          if (name.endsWith('.obb')) {
            final obbRemotePath = '$folderToUseObb\\$name';
            final obbLocalFile = File('${localObbDir.path}/$name');
            final size = await dl.getRemoteSize(obbRemotePath);
            if (size > 0) {
              obbFilesToDownload.add({
                'remotePath': obbRemotePath,
                'localFile': obbLocalFile,
                'size': size,
              });
              debugPrint('[InstallService] Found OBB: $name ($size bytes)');
            }
          }
        }
      } catch (e) {
        debugPrint('[InstallService] Error searching OBBs: $e');
      }

      // Calculate aggregated size
      for (var obb in obbFilesToDownload) {
        dl.totalSizeToDownload += obb['size'] as int;
      }
      dl.totalSizeToDownload += apkSize;

      debugPrint(
        '[InstallService] Total size to download: ${dl.totalSizeToDownload}',
      );

      // 3. Download sequence
      if (obbFilesToDownload.isNotEmpty) {
        if (!await localObbDir.exists()) {
          try {
            await localObbDir.create(recursive: true);
          } catch (e) {
            throw Exception('Permission denied for ${localObbDir.path}.');
          }
        }

        for (var obb in obbFilesToDownload) {
          final success = await dl.downloadFile(
            obb['remotePath'] as String,
            obb['localFile'] as File,
            obb['size'] as int,
          );
          if (!success) {
            throw Exception("Failed to download OBB: ${obb['remotePath']}");
          }
        }
      }

      onProgress('Downloading APK...');
      final apkSuccess = await dl.downloadFile(
        apkRemotePathToDownload,
        apkFile,
        apkSize,
      );
      if (!apkSuccess) {
        throw Exception('Failed to download APK');
      }

      debugPrint(
        '[InstallService] All files downloaded. Executing native install.',
      );
      onProgress('Triggering Native Install...');
      final result = await platform.invokeMethod('installApk', {
        'apkPath': apkFile.path,
      });

      if (result == true) {
        debugPrint('[InstallService] Native install intent successful.');
        onProgress('Installation Started!');
      } else {
        throw Exception('Installation Intent Failed.');
      }
    } catch (e) {
      debugPrint('[InstallService] Error: $e');
      throw Exception('Install Error: $e');
    } finally {
      await pool?.disconnect();
    }
  }
}

// ── SMB download helper ───────────────────────────────────────────────────────

/// Wraps a live [Smb2Pool] connection and provides [getRemoteSize] /
/// [downloadFile] helpers that share download-progress state.
class _SmbDownloader {
  final Smb2Pool pool;
  final void Function(String) onProgress;
  final void Function(double)? onDownloadProgress;
  final bool Function()? isCancelled;

  int totalSizeToDownload = 0;
  int totalDownloaded = 0;

  _SmbDownloader({
    required this.pool,
    required this.onProgress,
    this.onDownloadProgress,
    this.isCancelled,
  });

  Future<int> getRemoteSize(String remotePath) async {
    try {
      final exists = await pool.exists(remotePath);
      if (!exists) return 0;
      return await pool.fileSize(remotePath);
    } catch (e) {
      debugPrint('[InstallService] Error getting size for $remotePath: $e');
      return 0;
    }
  }

  Future<bool> downloadFile(String remotePath, File localFile, int size) async {
    try {
      debugPrint(
        '[InstallService] Downloading $remotePath -> ${localFile.path}',
      );
      onProgress('Downloading ${localFile.path.split('/').last}...');
      if (size == 0) return false;

      final stream = pool.streamFile(remotePath, chunkSize: 1024 * 1024 * 2);
      final sink = localFile.openWrite();

      try {
        int speedDownloaded = totalDownloaded;
        DateTime lastSpeedTime = DateTime.now();

        await for (final chunk in stream) {
          if (isCancelled != null && isCancelled!()) {
            throw Exception('Installation cancelled by user');
          }
          final chunkLen = (chunk as List<int>).length;
          sink.add(chunk);
          totalDownloaded += chunkLen;

          if (totalSizeToDownload > 0 && onDownloadProgress != null) {
            onDownloadProgress!(totalDownloaded / totalSizeToDownload);
          }

          final now = DateTime.now();
          final elapsed = now.difference(lastSpeedTime).inMilliseconds;
          if (elapsed >= 500) {
            final speedBytes = totalDownloaded - speedDownloaded;
            final speedMbps = (speedBytes / 1024 / 1024) / (elapsed / 1000);
            onProgress('${speedMbps.toStringAsFixed(1)} MB/s');
            speedDownloaded = totalDownloaded;
            lastSpeedTime = now;
          }

          // Yield to Flutter event loop so the progress bar can repaint.
          await Future.delayed(const Duration(milliseconds: 5));
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      final finalSize = await localFile.length();
      debugPrint('[InstallService] Downloaded $finalSize bytes.');
      return finalSize == size;
    } catch (e) {
      debugPrint('[InstallService] downloadFile error: $e');
      return false;
    }
  }
}
