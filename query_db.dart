// ignore_for_file: avoid_print
import 'dart:io';
import 'package:dart_smb2/dart_smb2.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  try {
    final host = "100.95.32.89";
    final share = "ssd_internal";
    final relativePath = "downloads/pico4/apps/apps.db";

    final pool = await Smb2Pool.connect(
      host: host,
      share: share,
      user: 'liakos',
      password: 'stella.elias.240922',
      workers: 1,
    );

    final data = await pool.readFile(relativePath);
    await pool.disconnect();

    final localPath = 'temp_apps.db';
    final localFile = File(localPath);
    await localFile.writeAsBytes(data);

    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(localPath);
    final apps = await db.query('apps', limit: 1);
    await db.close();
    
    if (apps.isNotEmpty) {
      print(apps.first.keys);
      print("\nSample values:");
      apps.first.forEach((k, v) => print("$k: $v"));
    } else {
      print("No apps found");
    }
    exit(0);
  } catch(e) {
    print("Error: $e");
    exit(1);
  }
}
