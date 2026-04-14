import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dart_smb2/dart_smb2.dart';

Future<List<Map<String, dynamic>>> fetchAppsFromDb(String smbUrl) async {
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

  final data = await pool.readFile(relativePath);
  await pool.disconnect();
  
  final directory = await getTemporaryDirectory();
  final localPath = '${directory.path}/apps.db';
  final localFile = File(localPath);
  await localFile.writeAsBytes(data);

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final db = await openDatabase(localPath);
  final apps = await db.query('apps');
  await db.close();
  return apps;
}
