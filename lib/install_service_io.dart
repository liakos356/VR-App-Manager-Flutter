import 'dart:io';
import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/services.dart';

class InstallService {
  static const platform = MethodChannel('com.vr.appmanager/install');

  static Future<void> installAppLocally({
    required String appId,
    required String apkPath,
    required String obbDir,
    required Function(String) onProgress,
  }) async {
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
      
      late List<int> apkData;
      bool apkFound = false;

      // Extract the relative path without the mount prefix since SMB starts at share root
      // E.g., /mnt/sda/downloads/... -> downloads/...
      String relativeApkPath = apkPath;
      if (relativeApkPath.startsWith('/mnt/sda/')) {
        relativeApkPath = relativeApkPath.substring('/mnt/sda/'.length);
      } else if (relativeApkPath.startsWith('/')) {
        relativeApkPath = relativeApkPath.substring(1);
      }
      
      // Try direct apk first using path from DB
      try {
        apkData = await pool.readFile(relativeApkPath);
        apkFound = true;
      } catch (e) {
        // If it fails, fallback to checking guessing based on appId
      }

      if (!apkFound) {
        onProgress('Checking alternate path downloads/pico4/apps/$appId.apk...');
        try {
          apkData = await pool.readFile('downloads/pico4/apps/$appId.apk');
          apkFound = true;
        } catch (e) {
          // Ignore if alternate path not found
        }
      }

      if (!apkFound) {
        // Try looking in a folder: downloads/pico4/apps/[appId]/
        onProgress('Checking folder downloads/pico4/apps/$appId...');
        final folder = 'downloads/pico4/apps/$appId';
        
        List<dynamic> files = [];
        try {
          files = await pool.listDirectory(folder);
        } catch (e) {
          // Ignore if folder not found
        }
        
        for (var f in files) {
          if (f.name.endsWith('.apk')) {
            onProgress('Downloading APK: ${f.name}...');
            apkData = await pool.readFile('$folder/${f.name}');
            apkFound = true;
            break;
          }
        }
        
        if (!apkFound) {
          throw Exception('No APK found for $appId on SMB');
        }

        // Also look for OBB files
        onProgress('Checking OBB...');
        final localObbDir = Directory('/sdcard/Android/obb/$appId');
        
        // Try reading from the specified obb directory in DB if available
        String relativeObbPath = obbDir;
        if (relativeObbPath.startsWith('/mnt/sda/')) {
          relativeObbPath = relativeObbPath.substring('/mnt/sda/'.length);
        } else if (relativeObbPath.startsWith('/')) {
          relativeObbPath = relativeObbPath.substring(1);
        }

        List<dynamic> obbFiles = [];
        try {
          if (relativeObbPath.isNotEmpty) {
            obbFiles = await pool.listDirectory(relativeObbPath);
          } else {
            obbFiles = await pool.listDirectory('downloads/pico4/apps/$appId');
          }
        } catch (e) {
          // No obb folder found
        }

        final folderToUse = relativeObbPath.isNotEmpty ? relativeObbPath : 'downloads/pico4/apps/$appId';
        
        for (var f in obbFiles) {
           if (f.name.endsWith('.obb')) {
             onProgress('Downloading OBB ${f.name}...');
             final obbData = await pool.readFile('$folderToUse/${f.name}');
             
             if (!await localObbDir.exists()) {
               await localObbDir.create(recursive: true);
             }
             final localObbFile = File('${localObbDir.path}/${f.name}');
             await localObbFile.writeAsBytes(obbData, flush: true);
           }
        }
      }

      onProgress('Writing APK locally...');
      await apkFile.writeAsBytes(apkData, flush: true);

      onProgress('Triggering Native Install...');
      final result = await platform.invokeMethod('installApk', {'apkPath': apkFile.path});
      if (result == true) {
         onProgress('Installation Started!');
      } else {
         throw Exception('Installation Intent Failed');
      }
    } catch (e) {
      throw Exception('Install Error: $e');
    } finally {
      await pool?.disconnect();
    }
  }
}
