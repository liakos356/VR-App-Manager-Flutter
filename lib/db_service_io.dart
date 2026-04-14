import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smb_connect/smb_connect.dart';

Future<List<Map<String, dynamic>>> fetchAppsFromDb(String smbUrl) async {
  final uri = Uri.parse(smbUrl);
  final host = uri.host;
  final path = uri.path;

  final connect = await SmbConnect.connectAuth(
    host: host.isNotEmpty ? host : "100.95.32.89",
    domain: "",
    username: "",
    password: "",
  );

  final smbFile = await connect.file(path);
  final reader = await connect.openRead(smbFile);
  
  final directory = await getTemporaryDirectory();
  final localPath = '${directory.path}/apps.db';
  final localFile = File(localPath);
  final ioSink = localFile.openWrite();
  
  await for (var data in reader) {
    ioSink.add(data);
  }
  await ioSink.flush();
  await ioSink.close();
  await connect.close();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final db = await openDatabase(localPath);
  final apps = await db.query('apps');
  await db.close();
  return apps;
}
