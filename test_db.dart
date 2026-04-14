import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase('test_apps.db');
  final result = await db.query('apps');
  for (var r in result) {
    if (r['trailer_url'] != null) {
      debugPrint(r['trailer_url'].toString());
    }
  }
  await db.close();
}
