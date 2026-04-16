import 'dart:io';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<List<Map<String, dynamic>>> fetchAppsFromDb(
  String smbUrl, {
  void Function(double)? onProgress,
  bool forceRefresh = false,
}) async {
  final uri = Uri.parse(smbUrl);
  final host = uri.host.isNotEmpty ? uri.host : "100.95.32.89";
  final pathSegments = uri.pathSegments;

  if (pathSegments.isEmpty) {
    throw Exception("Invalid SMB URL, no share defined.");
  }

  final share = pathSegments.first;
  final relativePath = pathSegments.skip(1).join('/');

  final pool = await Smb2Pool.connect(
    host: host,
    share: share,
    user: 'liakos',
    password: 'stella.elias.240922',
    workers: 1,
  );

  final directory = await getTemporaryDirectory();
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final localPath = '${directory.path}/apps.db';
  final localFile = File(localPath);

  try {
    final stat = await pool.stat(relativePath);
    final int totalSize = stat.size;
    final int chunkSize = 1024 * 1024; // 1 MB chunks

    bool needsDownload = true;
    if (!forceRefresh && await localFile.exists()) {
      final localStat = await localFile.stat();
      if (localStat.size == totalSize) {
        needsDownload = false;
      }
    }

    if (needsDownload) {
      if (totalSize > 0) {
        if (onProgress != null) onProgress(0.0);
        int downloaded = 0;
        final sink = localFile.openWrite();
        try {
          while (downloaded < totalSize) {
            final int length = (totalSize - downloaded < chunkSize)
                ? (totalSize - downloaded)
                : chunkSize;
            final chunk = await pool.readFileRange(
              relativePath,
              offset: downloaded,
              length: length,
            );
            sink.add(chunk);
            downloaded += chunk.length;
            if (onProgress != null) onProgress(downloaded / totalSize);
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      } else {
        if (onProgress != null) onProgress(-1.0); // Indeterminate
        final data = await pool.readFile(relativePath);
        await localFile.writeAsBytes(data);
        if (onProgress != null) onProgress(1.0);
      }
    } else {
      if (onProgress != null) onProgress(1.0);
    }
  } catch (e) {
    if (onProgress != null) onProgress(-1.0); // signal fallback
    final data = await pool.readFile(relativePath);
    await localFile.writeAsBytes(data);
    if (onProgress != null) onProgress(1.0);
  } finally {
    await pool.disconnect();
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final db = await openDatabase(localPath);
  final apps = await db.query('apps');
  await db.close();
  return apps;
}
