// ignore_for_file: avoid_print
import 'dart:io';
import 'package:dart_smb2/dart_smb2.dart';

void main() async {
  final pool = await Smb2Pool.connect(
    host: '100.95.32.89',
    share: 'ssd_internal',
    user: 'liakos',
    password: 'stella.elias.240922',
    workers: 1,
  );

  final data = await pool.readFile('downloads/pico4/apps/apps.db');
  await pool.disconnect();
  
  final localFile = File('downloaded_test.db');
  await localFile.writeAsBytes(data);
  print('DB downloaded!');
}
