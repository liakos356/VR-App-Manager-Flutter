// ignore_for_file: avoid_print
import 'package:appmanager/db_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('check db schema', () async {
    final result = await fetchAppsFromDb(
      'smb://100.95.32.89/ssd_internal/downloads/pico4/apps/apps.db',
    );
    print('APP COLUMNS_MAGIC_MARKER: ${result.apps.first.keys}');
  });
}
