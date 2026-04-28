import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:installed_apps/app_info.dart';

/// Provides enriched metadata for installed apps:
/// - APK disk size via a MethodChannel to Android's PackageManager
/// - Description matched from the local Supabase app catalog
///
/// All results are cached in memory so repeated calls are instant.
class AppEnrichmentService {
  AppEnrichmentService._();

  static final AppEnrichmentService instance = AppEnrichmentService._();

  static const _channel = MethodChannel('com.vr.appmanager/install');

  // ── Caches ────────────────────────────────────────────────────────────────

  /// packageName → total bytes on disk
  final Map<String, int> _sizeCache = {};

  /// packageName → description string
  final Map<String, String> _descriptionCache = {};

  // ── Size ──────────────────────────────────────────────────────────────────

  /// Returns the total bytes occupied by [app]'s APK file(s) on disk.
  /// Returns -1 if the information is unavailable.
  Future<int> getAppSizeBytes(AppInfo app) async {
    if (_sizeCache.containsKey(app.packageName)) {
      return _sizeCache[app.packageName]!;
    }
    // Only works on Android
    if (!Platform.isAndroid) {
      _sizeCache[app.packageName] = -1;
      return -1;
    }
    try {
      final bytes = await _channel.invokeMethod<int>('getApkSize', {
        'packageName': app.packageName,
      });
      final result = bytes ?? -1;
      _sizeCache[app.packageName] = result;
      return result;
    } catch (e) {
      debugPrint(
        '[AppEnrichmentService] size error for ${app.packageName}: $e',
      );
      _sizeCache[app.packageName] = -1;
      return -1;
    }
  }

  /// Returns a human-readable size string, e.g. "45.2 MB" or "1.3 GB".
  Future<String> getAppSizeLabel(AppInfo app) async {
    final bytes = await getAppSizeBytes(app);
    return formatBytes(bytes);
  }

  static String formatBytes(int bytes) {
    if (bytes < 0) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ── Description ───────────────────────────────────────────────────────────

  /// Looks up [packageName] in [dbApps] (from the local Supabase catalog) and
  /// returns the description string, or an empty string if not found.
  String getDescription(String packageName, List<dynamic> dbApps) {
    if (_descriptionCache.containsKey(packageName)) {
      return _descriptionCache[packageName]!;
    }
    final pkg = packageName.toLowerCase().trim();
    for (final app in dbApps) {
      final dbPkg = (app['package_name'] ?? '').toString().toLowerCase().trim();
      if (dbPkg.isNotEmpty && dbPkg == pkg) {
        final desc = (app['description'] ?? '').toString().trim();
        _descriptionCache[packageName] = desc;
        return desc;
      }
    }
    // Return empty but do NOT cache – caller should try fetchDescription() async.
    return '';
  }

  /// Fetches the description for [packageName].
  ///
  /// Priority:
  ///  1. In-memory cache (instant)
  ///  2. Local Supabase catalog [dbApps] (instant, exact package match)
  ///  3. Google Play Store meta description (network, ~1 s)
  ///
  /// Returns empty string if nothing is found.
  Future<String> fetchDescription(
    String packageName,
    List<dynamic> dbApps,
  ) async {
    // 1. Cache hit
    if (_descriptionCache.containsKey(packageName) &&
        _descriptionCache[packageName]!.isNotEmpty) {
      return _descriptionCache[packageName]!;
    }

    // 2. Local DB
    final fromDb = getDescription(packageName, dbApps);
    if (fromDb.isNotEmpty) return fromDb;

    // 3. Google Play Store
    final fromPlay = await _fetchPlayStoreDescription(packageName);
    if (fromPlay.isNotEmpty) {
      _descriptionCache[packageName] = fromPlay;
    }
    return fromPlay;
  }

  /// Scrapes the Google Play Store page for [packageName] and extracts the
  /// short meta description.  Returns empty string on any error.
  Future<String> _fetchPlayStoreDescription(String packageName) async {
    try {
      final uri = Uri.https('play.google.com', '/store/apps/details', {
        'id': packageName,
        'hl': 'en',
        'gl': 'US',
      });
      final response = await http
          .get(uri, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return '';

      // Try <meta name="description" content="...">
      final metaMatch = RegExp(
        r'<meta\s+name="description"\s+content="([^"]{10,})"',
        caseSensitive: false,
      ).firstMatch(response.body);
      if (metaMatch != null) {
        return _unescapeHtml(metaMatch.group(1) ?? '').trim();
      }
    } catch (e) {
      debugPrint('[AppEnrichmentService] Play Store fetch error: $e');
    }
    return '';
  }

  static String _unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', '\u00a0');
  }

  /// Returns the DB app record matching [packageName], or null.
  Map<String, dynamic>? getDbApp(String packageName, List<dynamic> dbApps) {
    final pkg = packageName.toLowerCase().trim();
    for (final app in dbApps) {
      final dbPkg = (app['package_name'] ?? '').toString().toLowerCase().trim();
      if (dbPkg.isNotEmpty && dbPkg == pkg) {
        return Map<String, dynamic>.from(app as Map);
      }
    }
    return null;
  }

  /// Clears all caches (call after a fresh install/uninstall cycle if needed).
  void clearCache() {
    _sizeCache.clear();
    _descriptionCache.clear();
  }
}
