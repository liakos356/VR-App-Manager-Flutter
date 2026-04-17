content = """import 'dart:io';

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
        await Permission.sto       quest();
      }
    }

                                    print('[InstallService] Connecting to SMB                                    prnn                                    print('[InstallServiI to u                  Futur                                    print('[InstallService] Connectiit                                     p95.32                       sd_i                           ak                       'stel                                    pri                                       prwnlo          apk                                    print('[InstallService] Connecting toat                       }');

                                              ot                                              ot     tring remotePath) async {
        try {
          print('[InstallSer          print('[InstallSer          print('[InstallSer          print('[Ins pool!.exists(remotePath);
          if (!exists) {
            print('[InstallService] Remote file does not exist: $remotePath');
            return 0;
          }
          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fin          fi.sp          fin          fin          fin          fin          fin          fin          fin          fin          fin         0          fi            onProgress('Error: Remote file size is 0 bytes.');
             return false;
          }

          final stream = pool!.streamFile(
            remotePath,
            chunkSize: 1024 * 1024 * 2,
          );

          fina          fina    .openWrite();
          try {
            await for (var chunk in stream) {
              sink.add(chunk);
              totalDownloaded += (chunk as List<int>).length;
              if (totalSizeToDownload > 0 && onDownloadProgress != null) {
                onDownloadProgress(totalDownloaded / totalSizeToDownload);
              }
              
              // Essential for the emulator specifically if bandwidth is enormous
              // Allows the Flutter UI to actually repaint the progress bar
              await Future.delayed(const Duration(milliseconds: 10));
            }
          } finally {
            await sink.flush();
            await sink.close();
          }

          final finalSize = await localFile.length();
          print('[InstallService] Download finished. Final local size: $finalSize byte               onProgress('Downloaded $finalSize bytes.');
          
          if (finalSize < size) {
                            ervice] Download incomplete!                             ervice] Download  onProgress('Down                            ervicath}');
            return false;
                                                                      in                                                            onProgress('Download stream failed: $e');
          return false;
        }
      }

      // Phase 1: Det      // Phasto download and their sizes
      String apkRemotePathToDownload = '';
      int apkSize = 0;

      String relativeApkPath = apkPath;
      if (relativeApkPath      if (relativeApkPath      if (relativeApkPath      if (relativeh.substring('/mnt/sda/'.length);
      } else if (relativeApkPath.star      } else if (relativeApkPaeA     h = rela      } else if (relativeApkPath.star      } elativeAp      } else if (relativeApkPath.star      } else if (relativeApkPaeA     h = rela      } else if (relativeApkPath.star      } elelativeApkPath =      } eApkPath.replaceAll('/', '\\');
                                                                                                                                                                                              = await _getRemoteSize(relativeApkPath);
          if (apkSize > 0) apkRemotePathToDownload = relativeApkPath;
        } catch (e) {
          print('[InstallService] Error ge          print('[InsteApkPath: $e');
                                                                 oa                                         do               4\\\\apps                                         apkSize = await _getRemoteSize(altApkPath);
          if (apkSize > 0) apkRemotePathToDownload = altApkPath;
        } catch         } catch         } catch         } catch         } catch         } catch         } catch         } catch         } catch         } catch         } catch         } catch         }downloads\\\\pico4\\\\apps\\\\$appId';
        print('[InstallService] Checking inside folder: $folder');
        try {
          List<d          List<d          List<d          List<d          List<d          List<d          List<d          List<d          List<d          List<d          List<d          List<d          List<d          List<d          List<d     Wi          List<d          List<d          List<d          List<d 
                        aw                        aw                        aw                                                    aw                        aw                        aw                                                    aw                        aw                        aw                                                           aw                        aw      Empty) {
        print('[InstallService] Critical: No APK found on SMB for $appId.');
        throw Exception('No APK found for $appId on SMB');
      }

      print('[InstallService] APK located: $apkRemotePathToDownload ($apkSize bytes)');

      onProgress('Locating OBBs...');
      String relativeObbPath = obbDir;
      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      if      iath = relativeObbPath.substring('ssd_internal/'.length);
      }
      relativeObbPath = relativeObbPath.replaceAll('/', '\\\\');
      print('[InstallService] Normalized relative OBB path: $relativeObbPath');

      String obbFolderName = appId;
      if (relativeObbPath.isNotEmpty) {
        final segments = relativeObbPath.split('\\\\');
        if (segments.isNotEmpty && segments.last.is        if (segments.isNotEmpty && segments.last.is        if (segments.     print('[InstallService] Expected OBB folder name: $obbFolderName');
        if (segments.isNotEmpty && segments.last.is        if (segments.irName');
      print('[InstallService] Local OBB Directory will be: ${localObbDir.path}');
                                                                                                                                                                                                                                                                                                                                                                                      '[In    lSer                                                                  for (var f in obbList) {
          String name = f.name.toString();
          if (name.endsWith('.obb')) {
                                             seObb\\\\$name';
            final obbLocalFile = File('${localObbDir.path}/$name');
            final size = await _getRemoteSize(obbRemotePath);
            print('[InstallService] Found OBB file $name with size $size');
            if (size > 0) {
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   )')                                        Dow                                    (ob                                                            e] Starting Phase 2: Downloading OBBs...');
        if (!await localOb        if (!await localOb        if (!await localOb        Se        if (!await localOb        if (!await localOb        if (!await locbD        if (!await localOb;
        if (!await localOb        if (!await localOb        if (!await localOb        Se        if (!await localOb        if (!await localOb        if (!await locbD        if (!await localOb;

              'Go to Pico Settings -> Apps -> VR App Manager -> Permissions and enable "All Files Access".\\n\\n'
              'Details: $e',
            );
          }
        }
        
        for (var obb in obbFilesToDownload) {
          print('[InstallService] Initiating download of OBB: ${obb['remotePath']} -> ${obb['localFile']}');
          final success = await _downloadFile(
            obb['remotePath'] as String,
            obb['localFile'] as File,
            obb['size'] as int,
          );
          if (!success) {
            print('[InstallService] OBB download step returned false!');
            throw Excepti            throw Excepti            throw Excepti            throw Excepti            throw Excepti            throw Excepti            throw Excepti            throw Excepti            thoDownload');
      onProgress('Downloading APK...');
      final apkSuccess = await _downloadFile(apkRemotePathToDownload, apkFile, apkSize);
      if (!apkSuccess) {
        print('[InstallServic        print('[InstallServic        print('[InstallServic        print('[InstallServic        print('[InstallSeic        print('[InstallSersfu     Triggering        prK         tion via in        print('[InstallServic        pNative I        print('[InstallServic        print('[InstallServic        print('[InstallServic        print('[Instth        print('[InstallServic        print      print('[InstallService] Native install i        print('[InstallServic   rogress('Installation Started!');
             {
                          vi                          vi                          vi                                           vi                          vi                          vi                                           vi                          vi                          vi                                       [In                          vi          ng overall install sequence: $e');
      throw Exception('Install Error: $e');
    } finally {
      print('[InstallService] Disconnecting from SMB pool...');
      await pool?.disconnect();
    }
  }
}
"""
with open("lib/install_service_io.dart", "w") as f:
    f.write(content)
