import 'dart:io';
import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/services.dart';

class InstallService {
  static const platform = MethodChannel('com.vr.appmanager/install');

  static Future<void> installAppLocally(
    String appId,
    Function(String) onProgress,
  ) async {
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
      
      // Let's assume the APK is downloads/pico4/apps/[appId].apk
      // Or downloads/pico4/apps/[appId]/[something].apk
      onProgress('Checking SMB for $appId.apk...');
      
      late List<int> apkData;
      bool apkFound = false;

      final directApk = 'downloads/pico4/apps/$appId.apk';
      
      // Try direct apk first
      try {
        apkData = await pool.readFile(directApk);
        apkFound = true;
      } catch (e) {
        // If it fails, maybe it's inside a folder?
      }

      if (!apkFound) {
        // Try looking in a folder: downloads/pico4/apps/[appId]/
        onProgress('Checking folder downloads/pico4/apps/$appId...');
        final folder = 'downloads/pico4/apps/$appId';
        final files = await pool.listDirectory(folder);
        
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
        for (var f in files) {
           if (f.name.endsWith('.obb')) {
             onProgress('Downloading OBB ${f.name}...');
             final obbData = await pool.readFile('$folder/${f.name}');
             
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
