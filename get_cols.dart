// ignore_for_file: avoid_print
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase('test_apps.db');
  final result = await db.query('apps', limit: 1);
  if (result.isNotEmpty) {
    print(result.first.keys.toList());
  }
}
