// ignore_for_file: avoid_print
import 'package:dart_smb2/dart_smb2.dart';

void main() async {
  try {
    print('Connecting...');
    final pool = await Smb2Pool.connect(
      host: '100.95.32.89',
      share: 'ssd_internal',
      user: 'liakos',
      password: 'stella.elias.240922',
      workers: 1,
    );
    print('Connected');
    
    final files = await pool.listDirectory('downloads\\pico4\\apps\\4');
    for (var f in files) {
      print('File object type: \${f.runtimeType}');
      print('File object: $f');
    }
    
    await pool.disconnect();
  } catch (e) {
    print('Error: $e');
  }
}
