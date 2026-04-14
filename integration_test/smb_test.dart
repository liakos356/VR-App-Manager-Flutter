// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:appmanager/db_service_io.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dump db', (tester) async {
    final apps = await fetchAppsFromDb("smb://100.95.32.89/ssd_internal/downloads/pico4/apps/apps.db");
    print("Found ${apps.length} apps");
    if (apps.isNotEmpty) {
      print("Keys: ${apps.first.keys.toList()}");
      for (var k in apps.first.keys) {
        print("$k: ${apps.first[k]}");
      }
    }
  });
}
