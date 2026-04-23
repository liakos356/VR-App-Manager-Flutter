import 'dart:io';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/google_drive_service.dart';

// ── SMB configuration ─────────────────────────────────────────────────────
// TODO: Move these to a build-time config or secure storage before releasing.
const String _kSmbHost = '100.95.32.89';
const String _kSmbShare = 'ssd_internal';
const String _kSmbUser = 'liakos';
const String _kSmbPassword = 'stella.elias.240922';

class InstallService {
  static const platform = MethodChannel('com.vr.appmanager/install');

  /// Attempts a silent install via `pm install` without a user dialog.
  ///
  /// Returns `true` on success. Requires the app to have been granted
  /// `INSTALL_PACKAGES` permission (e.g. via ADB developer shell):
  ///   adb shell pm grant com.vr.appmanager android.permission.INSTALL_PACKAGES
  ///
  /// Falls back gracefully: if this returns `false`, callers should use
  /// [platform.invokeMethod('installApk', ...)] for the standard UI flow.
  static Future<bool> silentInstallApk(String apkPath) async {
    try {
      final result = await platform.invokeMethod<bool>('silentInstallApk', {
        'apkPath': apkPath,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('[InstallService] silentInstallApk failed: $e');
      return false;
    }
  }

  static Future<void> installAppLocally({
    required String appId,
    required String apkPath,
    required String obbDir,
    required Function(String) onProgress,
    Function(double)? onDownloadProgress,
    bool Function()? isCancelled,
  }) async {
    // Route Google Drive installs to the dedicated method.
    if (GoogleDriveService.isDrivePath(apkPath) ||
        GoogleDriveService.isDrivePath(obbDir)) {
      return _installFromDrive(
        appId: appId,
        apkPath: apkPath,
        obbDir: obbDir,
        onProgress: onProgress,
        onDownloadProgress: onDownloadProgress,
        isCancelled: isCancelled,
      );
    }

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

    // ── Try Google Drive first ────────────────────────────────────────────
    {
      final driveService = GoogleDriveService();
      if (driveService.isSignedIn) {
        // Derive the APK filename from the stored path (or fall back to appId)
        String apkFileName = apkPath.replaceAll('\\', '/').split('/').last;
        if (apkFileName.isEmpty || !apkFileName.endsWith('.apk')) {
          apkFileName = '$appId.apk';
        }

        onProgress('Searching Google Drive...');
        debugPrint('[InstallService] Trying Drive first for "$apkFileName"');
        try {
          final driveFile = await driveService.findFileByName(apkFileName);
          if (driveFile != null && driveFile.id != null) {
            final size = int.tryParse(driveFile.size ?? '0') ?? 0;
            if (size > 0) {
              debugPrint(
                '[InstallService] Found on Drive: ${driveFile.id} ($size bytes) — skipping SMB',
              );
              return _installFromDriveByFileId(
                appId: appId,
                apkFileId: driveFile.id!,
                apkSize: size,
                obbDir: obbDir,
                onProgress: onProgress,
                onDownloadProgress: onDownloadProgress,
                isCancelled: isCancelled,
              );
            }
          }
        } catch (e) {
          debugPrint(
            '[InstallService] Drive search failed, falling back to SMB: $e',
          );
        }
        debugPrint('[InstallService] Not found on Drive, trying SMB...');
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

      int totalSizeToDownload = 0;
      int totalDownloaded = 0;

      Future<int> getRemoteSize(String remotePath) async {
        try {
          final exists = await pool!.exists(remotePath);
          if (!exists) return 0;
          return await pool.fileSize(remotePath);
        } catch (e) {
          debugPrint('[InstallService] Error getting size for $remotePath: $e');
          return 0;
        }
      }

      Future<bool> downloadFile(
        String remotePath,
        File localFile,
        int size,
      ) async {
        try {
          debugPrint(
            '[InstallService] Downloading $remotePath -> ${localFile.path}',
          );
          onProgress('Downloading ${localFile.path.split('/').last}...');
          if (size == 0) return false;

          final stream = pool!.streamFile(
            remotePath,
            chunkSize: 1024 * 1024 * 2,
          );
          final sink = localFile.openWrite();

          try {
            int speedDownloaded = totalDownloaded;
            DateTime lastSpeedTime = DateTime.now();

            await for (var chunk in stream) {
              if (isCancelled != null && isCancelled()) {
                throw Exception('Installation cancelled by user');
              }
              final chunkLen = (chunk as List<int>).length;
              sink.add(chunk);
              totalDownloaded += chunkLen;
              if (totalSizeToDownload > 0 && onDownloadProgress != null) {
                onDownloadProgress(totalDownloaded / totalSizeToDownload);
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

              // Yield to Flutter event loop so UI can paint the progress bar
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
          debugPrint('[InstallService] _downloadFile error: $e');
          return false;
        }
      }

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
        apkSize = await getRemoteSize(relativeApkPath);
        if (apkSize > 0) apkRemotePathToDownload = relativeApkPath;
      }

      if (apkSize == 0 || apkRemotePathToDownload.isEmpty) {
        final altApkPath = 'downloads\\pico4\\apps\\$appId.apk';
        apkSize = await getRemoteSize(altApkPath);
        if (apkSize > 0) apkRemotePathToDownload = altApkPath;
      }

      // Fallback: list the parent directory of the primary path and use
      // directory-entry sizes (avoids the stat round-trip that may fail on
      // some SMB servers with Smb2ErrorType.unknown).
      if ((apkSize == 0 || apkRemotePathToDownload.isEmpty) &&
          relativeApkPath.isNotEmpty) {
        final lastSep = relativeApkPath.lastIndexOf('\\');
        if (lastSep > 0) {
          final parentDir = relativeApkPath.substring(0, lastSep);
          try {
            final List<Smb2DirEntry> entries = await pool.listDirectory(
              parentDir,
            );
            for (final entry in entries) {
              if (entry.name.endsWith('.apk') && entry.size > 0) {
                apkSize = entry.size;
                apkRemotePathToDownload = '$parentDir\\${entry.name}';
                debugPrint(
                  '[InstallService] Found APK via dir listing: $apkRemotePathToDownload ($apkSize bytes)',
                );
                break;
              }
            }
          } catch (e) {
            debugPrint(
              '[InstallService] Error listing parent dir $parentDir: $e',
            );
          }
        }
      }

      if (apkSize == 0 || apkRemotePathToDownload.isEmpty) {
        final folder = 'downloads\\pico4\\apps\\$appId';
        try {
          final List<Smb2DirEntry> files = await pool.listDirectory(folder);
          for (final entry in files) {
            if (entry.name.endsWith('.apk') && entry.size > 0) {
              apkSize = entry.size;
              apkRemotePathToDownload = '$folder\\${entry.name}';
              break;
            }
          }
        } catch (e) {
          debugPrint('[InstallService] Error listing dir $folder: $e');
        }
      }

      // Last resort: search Google Drive by the APK filename
      if (apkSize == 0 || apkRemotePathToDownload.isEmpty) {
        final driveService = GoogleDriveService();
        if (driveService.isSignedIn) {
          String apkFileName = '';
          if (relativeApkPath.isNotEmpty) {
            final lastSep = relativeApkPath.lastIndexOf('\\');
            apkFileName = lastSep >= 0
                ? relativeApkPath.substring(lastSep + 1)
                : relativeApkPath;
          }
          if (apkFileName.isEmpty) apkFileName = '$appId.apk';

          onProgress('Searching Google Drive...');
          debugPrint(
            '[InstallService] SMB failed; searching Drive for "$apkFileName"',
          );
          try {
            final driveFile = await driveService.findFileByName(apkFileName);
            if (driveFile != null && driveFile.id != null) {
              final size = int.tryParse(driveFile.size ?? '0') ?? 0;
              if (size > 0) {
                debugPrint(
                  '[InstallService] Found on Drive: ${driveFile.id} ($size bytes)',
                );
                await pool.disconnect();
                pool = null;
                await _installFromDriveByFileId(
                  appId: appId,
                  apkFileId: driveFile.id!,
                  apkSize: size,
                  obbDir: obbDir,
                  onProgress: onProgress,
                  onDownloadProgress: onDownloadProgress,
                  isCancelled: isCancelled,
                );
                return;
              }
            }
          } catch (e) {
            debugPrint('[InstallService] Drive fallback search error: $e');
          }
        }
        throw Exception('No APK found for $appId on SMB or Google Drive');
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
            final size = await getRemoteSize(obbRemotePath);
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
        totalSizeToDownload += obb['size'] as int;
      }
      totalSizeToDownload += apkSize;

      debugPrint(
        '[InstallService] Total size to download: $totalSizeToDownload',
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
          final success = await downloadFile(
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
      final apkSuccess = await downloadFile(
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
      final silentOk = await silentInstallApk(apkFile.path);
      if (silentOk) {
        debugPrint('[InstallService] Silent install succeeded.');
        onProgress('Installed!');
      } else {
        debugPrint(
          '[InstallService] Silent install unavailable; using UI intent.',
        );
        final result = await platform.invokeMethod('installApk', {
          'apkPath': apkFile.path,
        });
        if (result == true) {
          debugPrint('[InstallService] Native install intent successful.');
          onProgress('Installation Started!');
        } else {
          throw Exception('Installation Intent Failed.');
        }
      }
    } catch (e) {
      debugPrint('[InstallService] Error: $e');
      throw Exception('Install Error: $e');
    } finally {
      await pool?.disconnect();
    }
  }

  // ── Google Drive install path ─────────────────────────────────────────────

  static Future<void> _installFromDrive({
    required String appId,
    required String apkPath,
    required String obbDir,
    required Function(String) onProgress,
    Function(double)? onDownloadProgress,
    bool Function()? isCancelled,
  }) async {
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

    final driveService = GoogleDriveService();
    if (!driveService.isSignedIn) {
      throw Exception(
        'Not signed in to Google Drive. Please sign in via Settings first.',
      );
    }

    debugPrint('[InstallService] Starting Google Drive install for $appId...');
    onProgress('Connecting to Google Drive...');
    await Future.delayed(const Duration(milliseconds: 50));

    final apkFile = File('/sdcard/Download/$appId.apk');
    int totalSizeToDownload = 0;
    int totalDownloaded = 0;

    Future<bool> downloadDriveFile(
      String fileId,
      File localFile,
      int size,
    ) async {
      if (size == 0) return false;
      onProgress('Downloading ${localFile.path.split('/').last}...');
      int lastReceived = 0;
      int speedTracker = totalDownloaded;
      DateTime lastSpeedTime = DateTime.now();

      try {
        await driveService.downloadFile(
          fileId: fileId,
          localFile: localFile,
          fileSize: size,
          onProgress: (received, total) {
            final delta = received - lastReceived;
            lastReceived = received;
            totalDownloaded += delta;

            if (totalSizeToDownload > 0 && onDownloadProgress != null) {
              onDownloadProgress(totalDownloaded / totalSizeToDownload);
            }

            final now = DateTime.now();
            final elapsed = now.difference(lastSpeedTime).inMilliseconds;
            if (elapsed >= 500) {
              final speedBytes = totalDownloaded - speedTracker;
              final speedMbps = (speedBytes / 1024 / 1024) / (elapsed / 1000);
              onProgress('${speedMbps.toStringAsFixed(1)} MB/s');
              speedTracker = totalDownloaded;
              lastSpeedTime = now;
            }
          },
          isCancelled: isCancelled,
        );
        final finalSize = await localFile.length();
        debugPrint('[InstallService] Downloaded $finalSize bytes.');
        return finalSize == size;
      } catch (e) {
        debugPrint('[InstallService] Drive download error: $e');
        rethrow;
      }
    }

    // 1. Resolve APK
    onProgress('Locating APK on Google Drive...');
    final apkFileId = await driveService.resolveFileId(apkPath);
    if (apkFileId == null) {
      throw Exception('APK not found on Google Drive: $apkPath');
    }
    final apkSize = await driveService.getFileSize(apkFileId);
    if (apkSize == 0) {
      throw Exception('APK has zero size on Google Drive: $apkPath');
    }
    debugPrint('[InstallService] Drive APK → $apkFileId ($apkSize bytes)');

    // 2. Resolve OBBs
    onProgress('Locating OBBs...');
    String obbFolderName = appId;
    final obbFilesToDownload = <Map<String, dynamic>>[];

    if (GoogleDriveService.isDrivePath(obbDir)) {
      final parts = obbDir
          .replaceAll('\\', '/')
          .split('/')
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) obbFolderName = parts.last;

      try {
        final files = await driveService.listFiles(obbDir);
        for (final f in files) {
          final name = f.name ?? '';
          if (name.endsWith('.obb') && f.id != null) {
            final size = int.tryParse(f.size ?? '0') ?? 0;
            if (size > 0) {
              obbFilesToDownload.add({
                'fileId': f.id,
                'name': name,
                'size': size,
              });
              debugPrint(
                '[InstallService] Found Drive OBB: $name ($size bytes)',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[InstallService] Error listing OBBs on Drive: $e');
      }
    }

    // Total size
    totalSizeToDownload = apkSize;
    for (final obb in obbFilesToDownload) {
      totalSizeToDownload += obb['size'] as int;
    }

    // 3. Download OBBs
    if (obbFilesToDownload.isNotEmpty) {
      final localObbDir = Directory('/sdcard/Android/obb/$obbFolderName');
      if (!await localObbDir.exists()) {
        try {
          await localObbDir.create(recursive: true);
        } catch (e) {
          throw Exception('Permission denied for ${localObbDir.path}.');
        }
      }
      for (final obb in obbFilesToDownload) {
        final localFile = File('${localObbDir.path}/${obb['name'] as String}');
        final success = await downloadDriveFile(
          obb['fileId'] as String,
          localFile,
          obb['size'] as int,
        );
        if (!success) {
          throw Exception('Failed to download OBB: ${obb['name']}');
        }
      }
    }

    // 4. Download APK
    onProgress('Downloading APK...');
    final apkSuccess = await downloadDriveFile(apkFileId, apkFile, apkSize);
    if (!apkSuccess) {
      throw Exception('Failed to download APK from Google Drive');
    }

    // 5. Trigger native install
    debugPrint('[InstallService] All Drive files downloaded. Installing...');
    onProgress('Triggering Native Install...');
    final silentOk = await silentInstallApk(apkFile.path);
    if (silentOk) {
      debugPrint('[InstallService] Silent install succeeded.');
      onProgress('Installed!');
    } else {
      debugPrint(
        '[InstallService] Silent install unavailable; using UI intent.',
      );
      final result = await platform.invokeMethod('installApk', {
        'apkPath': apkFile.path,
      });
      if (result == true) {
        debugPrint('[InstallService] Native install intent successful.');
        onProgress('Installation Started!');
      } else {
        throw Exception('Installation Intent Failed.');
      }
    }
  }

  // ── Drive install with pre-resolved file ID ───────────────────────────────
  // Used when SMB resolution fails and the APK is found on Google Drive.

  static Future<void> _installFromDriveByFileId({
    required String appId,
    required String apkFileId,
    required int apkSize,
    required String obbDir,
    required Function(String) onProgress,
    Function(double)? onDownloadProgress,
    bool Function()? isCancelled,
  }) async {
    final driveService = GoogleDriveService();
    if (!driveService.isSignedIn) {
      throw Exception(
        'Not signed in to Google Drive. Please sign in via Settings first.',
      );
    }

    debugPrint('[InstallService] Drive-by-ID install for $appId: $apkFileId');

    final apkFile = File('/sdcard/Download/$appId.apk');
    int totalSizeToDownload = apkSize;
    int totalDownloaded = 0;

    Future<bool> downloadDriveFile(
      String fileId,
      File localFile,
      int size,
    ) async {
      if (size == 0) return false;
      onProgress('Downloading ${localFile.path.split('/').last}...');
      int lastReceived = 0;
      int speedTracker = totalDownloaded;
      DateTime lastSpeedTime = DateTime.now();
      try {
        await driveService.downloadFile(
          fileId: fileId,
          localFile: localFile,
          fileSize: size,
          onProgress: (received, total) {
            final delta = received - lastReceived;
            lastReceived = received;
            totalDownloaded += delta;
            if (totalSizeToDownload > 0 && onDownloadProgress != null) {
              onDownloadProgress(totalDownloaded / totalSizeToDownload);
            }
            final now = DateTime.now();
            final elapsed = now.difference(lastSpeedTime).inMilliseconds;
            if (elapsed >= 500) {
              final speedBytes = totalDownloaded - speedTracker;
              final speedMbps = (speedBytes / 1024 / 1024) / (elapsed / 1000);
              onProgress('${speedMbps.toStringAsFixed(1)} MB/s');
              speedTracker = totalDownloaded;
              lastSpeedTime = now;
            }
          },
          isCancelled: isCancelled,
        );
        final finalSize = await localFile.length();
        debugPrint('[InstallService] Downloaded $finalSize bytes.');
        return finalSize == size;
      } catch (e) {
        debugPrint('[InstallService] Drive download error: $e');
        rethrow;
      }
    }

    // Resolve OBBs (only if obbDir is a Drive path)
    onProgress('Locating OBBs...');
    String obbFolderName = appId;
    final obbFilesToDownload = <Map<String, dynamic>>[];

    if (GoogleDriveService.isDrivePath(obbDir)) {
      final parts = obbDir
          .replaceAll('\\', '/')
          .split('/')
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) obbFolderName = parts.last;
      try {
        final files = await driveService.listFiles(obbDir);
        for (final f in files) {
          final name = f.name ?? '';
          if (name.endsWith('.obb') && f.id != null) {
            final size = int.tryParse(f.size ?? '0') ?? 0;
            if (size > 0) {
              obbFilesToDownload.add({
                'fileId': f.id,
                'name': name,
                'size': size,
              });
              totalSizeToDownload += size;
              debugPrint(
                '[InstallService] Found Drive OBB: $name ($size bytes)',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[InstallService] Error listing OBBs on Drive: $e');
      }
    }

    // Download OBBs
    if (obbFilesToDownload.isNotEmpty) {
      final localObbDir = Directory('/sdcard/Android/obb/$obbFolderName');
      if (!await localObbDir.exists()) {
        try {
          await localObbDir.create(recursive: true);
        } catch (e) {
          throw Exception('Permission denied for ${localObbDir.path}.');
        }
      }
      for (final obb in obbFilesToDownload) {
        final localFile = File('${localObbDir.path}/${obb['name'] as String}');
        final success = await downloadDriveFile(
          obb['fileId'] as String,
          localFile,
          obb['size'] as int,
        );
        if (!success) {
          throw Exception('Failed to download OBB: ${obb['name']}');
        }
      }
    }

    // Download APK
    onProgress('Downloading APK...');
    final apkSuccess = await downloadDriveFile(apkFileId, apkFile, apkSize);
    if (!apkSuccess) {
      throw Exception('Failed to download APK from Google Drive');
    }

    // Trigger native install
    debugPrint('[InstallService] All Drive files downloaded. Installing...');
    onProgress('Triggering Native Install...');
    final silentOk = await silentInstallApk(apkFile.path);
    if (silentOk) {
      debugPrint('[InstallService] Silent install succeeded.');
      onProgress('Installed!');
    } else {
      debugPrint(
        '[InstallService] Silent install unavailable; using UI intent.',
      );
      final result = await platform.invokeMethod('installApk', {
        'apkPath': apkFile.path,
      });
      if (result == true) {
        debugPrint('[InstallService] Native install intent successful.');
        onProgress('Installation Started!');
      } else {
        throw Exception('Installation Intent Failed.');
      }
    }
  }
}
