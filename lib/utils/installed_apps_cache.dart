import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

/// Shared cache for the device's installed-apps list.
///
/// [InstalledApps.getInstalledApps] is an expensive OS IPC call.  Without a
/// cache every [AppCard] fires it independently on [initState], causing dozens
/// of simultaneous IPC round-trips every time the grid is built or scrolled.
///
/// [get] coalesces concurrent callers: the first caller fetches from the OS;
/// every subsequent caller within [_ttl] receives the cached snapshot without
/// any additional IPC.  Call [invalidate] after an install or uninstall so the
/// next [get] call picks up the new state.
class InstalledAppsCache {
  InstalledAppsCache._();

  static List<AppInfo>? _cache;
  static DateTime? _lastFetch;
  static Future<List<AppInfo>>? _pendingFetch;
  static const Duration _ttl = Duration(seconds: 30);

  /// Returns the installed-apps list, fetching it from the OS when the cache
  /// is empty or stale.  Concurrent callers share the same in-flight future so
  /// only one IPC call is ever in-flight at a time.
  static Future<List<AppInfo>> get() {
    final now = DateTime.now();
    if (_cache != null &&
        _lastFetch != null &&
        now.difference(_lastFetch!) < _ttl) {
      return Future.value(_cache);
    }
    _pendingFetch ??= _fetch().whenComplete(() => _pendingFetch = null);
    return _pendingFetch!;
  }

  /// Forces the next [get] call to re-query the OS.
  /// Call this immediately after a successful install or uninstall.
  static void invalidate() {
    _cache = null;
    _lastFetch = null;
  }

  static Future<List<AppInfo>> _fetch() async {
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: false,
      );
      _cache = apps;
      _lastFetch = DateTime.now();
      return apps;
    } catch (e) {
      debugPrint('[InstalledAppsCache] fetch failed: $e');
      return _cache ?? [];
    }
  }
}
