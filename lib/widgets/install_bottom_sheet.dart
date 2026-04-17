import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';

import '../install_service.dart';
import '../utils/localization.dart';

/// Opens a bottom sheet to install or uninstall [app].
///
/// [isInstalled] / [installedPackageName] describe the current state so the
/// sheet shows the correct action immediately.  [onInstallDone] is called after
/// a successful install or uninstall so the caller can refresh its state.
void showInstallBottomSheet(
  BuildContext context, {
  required dynamic app,
  required bool isInstalled,
  required String installedPackageName,
  required VoidCallback onInstallDone,
}) {
  final apkPath = app['file_path_apk']?.toString() ?? '';
  if (apkPath.trim().isEmpty) return;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _InstallSheet(
      app: app,
      isInstalled: isInstalled,
      installedPackageName: installedPackageName,
      onInstallDone: onInstallDone,
    ),
  );
}

// ---------------------------------------------------------------------------

class _InstallSheet extends StatefulWidget {
  final dynamic app;
  final bool isInstalled;
  final String installedPackageName;
  final VoidCallback onInstallDone;

  const _InstallSheet({
    required this.app,
    required this.isInstalled,
    required this.installedPackageName,
    required this.onInstallDone,
  });

  @override
  State<_InstallSheet> createState() => _InstallSheetState();
}

class _InstallSheetState extends State<_InstallSheet> {
  bool _installing = false;
  double _progress = 0.0;
  String _status = 'Starting...';

  String get _appName => widget.app['name'] ?? widget.app['title'] ?? 'App';

  Future<void> _startInstall() async {
    final String appId = widget.app['id']?.toString() ?? '';
    if (appId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Invalid Object: App ID is empty')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _installing = true;
      _progress = 0.0;
      _status = 'Starting...';
    });
    try {
      await InstallService.installAppLocally(
        appId: appId,
        apkPath: widget.app['file_path_apk']?.toString() ?? '',
        obbDir: widget.app['file_path_obb']?.toString() ?? '',
        onProgress: (s) => setState(() => _status = s),
        onDownloadProgress: (p) {
          if (p >= 0.0 && p <= 1.0) setState(() => _progress = p);
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Installation Completed!')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Installation Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _startUninstall() async {
    if (widget.installedPackageName.isEmpty) return;
    try {
      await InstalledApps.uninstallApp(widget.installedPackageName);
      await Future.delayed(const Duration(seconds: 1));
      widget.onInstallDone();
      if (mounted) Navigator.pop(context);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.isInstalled ? tr('Uninstall') : tr('Install')} $_appName?',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            widget.isInstalled
                ? tr('This will uninstall the app from your headset.')
                : tr(
                    'Do you want to send this app to your headset for installation?',
                  ),
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: _installing
                    ? null
                    : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: Text(tr('Cancel'), style: const TextStyle(fontSize: 18)),
              ),
              _InstallProgressButton(
                isInstalled: widget.isInstalled,
                installing: _installing,
                progress: _progress,
                status: _status,
                onTap: _installing
                    ? null
                    : (widget.isInstalled ? _startUninstall : _startInstall),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// A pill button that shows a progress fill while an install is in flight.
class _InstallProgressButton extends StatelessWidget {
  final bool isInstalled;
  final bool installing;
  final double progress;
  final String status;
  final VoidCallback? onTap;

  const _InstallProgressButton({
    required this.isInstalled,
    required this.installing,
    required this.progress,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = installing
        ? Colors.grey.shade800
        : (isInstalled ? Colors.red.shade600 : Colors.green.shade600);

    final label = installing
        ? (progress > 0.0 && progress < 1.0
              ? '${(progress * 100).toInt()}%'
              : status)
        : (isInstalled ? tr('Uninstall') : tr('Install'));

    return Container(
      height: 55,
      width: 200,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          if (installing)
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(color: Colors.green.shade600),
              ),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
