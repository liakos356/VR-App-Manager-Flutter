// ignore_for_file: avoid_print
import 'dart:io';
import 'package:appmanager/db_service.dart';
void main() async { try { final apps = await fetchAppsFromDb('smb://100.95.32.89/ssd_internal/downloads/pico4/apps/apps.db'); if (apps.isNotEmpty) { print('APP COLUMNS_MAGIC_MARKER: ${apps.first.keys}'); exit(0); } } catch(e) { print('Error: $e'); exit(1); } }
