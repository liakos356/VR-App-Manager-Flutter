import 'package:flutter/foundation.dart';

import 'installed_apps_cache.dart';

/// Result of checking whether an app is currently installed on the device.
typedef InstallCheckResult = ({
  bool isInstalled,
  String packageName,
  String installedVersion,
});

/// Returns an [InstallCheckResult] for [app] by querying the device's
/// installed-apps list using multiple matching strategies:
///
/// - Exact package-name match against `package_name` or `id` fields.
/// - APK-path substring match.
/// - Fuzzy title match (strips non-alpha chars then checks containment).
///
/// Uses [InstalledAppsCache] so all concurrent card-level checks share a
/// single IPC call rather than each firing their own.
Future<InstallCheckResult> checkAppInstalled(dynamic app) async {
  try {
    final installedList = await InstalledAppsCache.get();

    final title = (app['title']?.toString() ?? '').toLowerCase();
    final apkPath = (app['file_path_apk']?.toString() ?? '').toLowerCase();
    final id = (app['id']?.toString() ?? '').toLowerCase();
    final dbPackage = (app['package_name']?.toString() ?? '').toLowerCase();
    final nonAlpha = RegExp(r'[^a-zA-Z]');
    final cleanTitle = title.replaceAll(nonAlpha, '');

    for (final a in installedList) {
      if (a.packageName.isEmpty) continue;
      final pkgName = a.packageName.trim().toLowerCase();
      final cleanPkg = pkgName
          .replaceAll('com.', '')
          .replaceAll('org.', '')
          .replaceAll('net.', '')
          .replaceAll('co.', '')
          .replaceAll(nonAlpha, '');

      final fuzzyMatch =
          cleanTitle.isNotEmpty &&
          cleanPkg.isNotEmpty &&
          (cleanTitle.contains(cleanPkg) || cleanPkg.contains(cleanTitle));

      if (apkPath.contains(pkgName) ||
          id == pkgName ||
          id.contains(pkgName) ||
          dbPackage == pkgName ||
          dbPackage.contains(pkgName) ||
          a.name.toLowerCase().contains(title) ||
          fuzzyMatch) {
        return (
          isInstalled: true,
          packageName: a.packageName.trim(),
          installedVersion: a.versionName.trim(),
        );
      }
    }
  } catch (e) {
    debugPrint('[installChecker] $e');
  }
  return (isInstalled: false, packageName: '', installedVersion: '');
}
