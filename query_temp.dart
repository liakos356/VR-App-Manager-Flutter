import "package:flutter/foundation.dart";

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
void main() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase('${Directory.current.path}/temp_apps.db');
  final apps = await db.query('apps', limit: 1);
  if (apps.isNotEmpty) {
    for (var k in apps.first.keys) {
      debugPrint("$k: \${apps.first[k]}");
    }
  }
}
