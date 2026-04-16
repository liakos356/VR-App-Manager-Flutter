// ignore_for_file: avoid_print, unused_local_variable
import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SMB connection Test', () async {
    final pool = await Smb2Pool.connect(
      host: '100.95.32.89',
      share: 'ssd_internal',
      user: 'liakos',
      password: 'stella.elias.240922',
      workers: 1,
    );
    
    final files = await pool.listDirectory('downloads\\pico4\\apps\\4');
    for (var f in files) {
       print('File name: \${f.name}');
    }
    
    await pool.disconnect();
  });
}
