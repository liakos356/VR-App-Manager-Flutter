import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';

import '../install_service.dart';
import '../utils/installed_apps_cache.dart';
import '../utils/localization.dart';
import '../utils/spatial_theme.dart';

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
  final apkPath = app['apk_path']?.toString() ?? '';
  if (apkPath.trim().isEmpty) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.60),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius)),
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
  bool _cancelled = false;
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
      _cancelled = false;
      _progress = 0.0;
      _status = 'Starting...';
    });
    try {
      await InstallService.installAppLocally(
        appId: appId,
        apkPath: widget.app['apk_path']?.toString() ?? '',
        obbDir: widget.app['obb_dir']?.toString() ?? '',
        onProgress: (s) => setState(() => _status = s),
        onDownloadProgress: (p) {
          if (p >= 0.0 && p <= 1.0) setState(() => _progress = p);
        },
        isCancelled: () => _cancelled,
      );
      InstalledAppsCache.invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Installation Completed!')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && !_cancelled) {
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
      InstalledAppsCache.invalidate();
      await Future.delayed(const Duration(seconds: 1));
      widget.onInstallDone();
      if (mounted) Navigator.pop(context);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: kBlurModal, sigmaY: kBlurModal),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(kRadius),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: kLightCatchBright),
                width: 1.0,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  '${widget.isInstalled ? tr('Uninstall') : tr('Install')} $_appName?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isInstalled
                      ? tr('This will uninstall the app from your headset.')
                      : tr(
                          'Do you want to send this app to your headset for installation?',
                        ),
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.65)
                        : Colors.black.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_installing)
                      _SpatialActionButton(
                        onPressed: () => setState(() => _cancelled = true),
                        isDark: isDark,
                        accentColor: Colors.redAccent,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stop_circle_outlined,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('Cancel'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _SpatialActionButton(
                        onPressed: () => Navigator.of(context).pop(),
                        isDark: isDark,
                        child: Text(
                          tr('Cancel'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.80)
                                : Colors.black.withValues(alpha: 0.70),
                          ),
                        ),
                      ),
                    _InstallProgressButton(
                      isInstalled: widget.isInstalled,
                      installing: _installing,
                      progress: _progress,
                      status: _status,
                      isDark: isDark,
                      accent: accent,
                      onTap: _installing
                          ? null
                          : (widget.isInstalled
                              ? _startUninstall
                              : _startInstall),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
  final bool isDark;
  final Color accent;
  final VoidCallback? onTap;

  const _InstallProgressButton({
    required this.isInstalled,
    required this.installing,
    required this.progress,
    required this.status,
    required this.isDark,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color buttonColor = installing
        ? Colors.grey.shade700
        : (isInstalled ? Colors.redAccent.shade400 : Colors.green.shade500);

    final label = installing
        ? (progress > 0.0 && progress < 1.0
            ? '${(progress * 100).toInt()}%'
            : status)
        : (isInstalled ? tr('Uninstall') : tr('Install'));

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutQuint,
            height: 52,
            width: 180,
            decoration: BoxDecoration(
              color: buttonColor.withValues(alpha: onTap != null ? 0.90 : 0.50),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: buttonColor.withValues(alpha: 0.80),
                width: 1.0,
              ),
              boxShadow: onTap != null
                  ? [
                      BoxShadow(
                        color: buttonColor.withValues(alpha: 0.40),
                        blurRadius: kGlowBlur,
                        spreadRadius: kGlowSpread,
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (installing && progress > 0.0)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A generic ghost/outlined action button for the install sheet.
class _SpatialActionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool isDark;
  final Color? accentColor;

  const _SpatialActionButton({
    required this.child,
    required this.onPressed,
    required this.isDark,
    this.accentColor,
  });

  @override
  State<_SpatialActionButton> createState() => _SpatialActionButtonState();
}

class _SpatialActionButtonState extends State<_SpatialActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: _pressed ? 0.95 : 1.0),
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutQuint,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: widget.accentColor != null
                    ? widget.accentColor!.withValues(alpha: _pressed ? 0.70 : 0.85)
                    : Colors.white.withValues(
                        alpha: widget.isDark ? 0.08 : 0.40,
                      ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: widget.accentColor != null
                      ? widget.accentColor!.withValues(alpha: 0.80)
                      : Colors.white.withValues(alpha: kLightCatchBright),
                  width: 1.0,
                ),
                boxShadow: _pressed
                    ? []
                    : widget.accentColor != null
                    ? [
                        BoxShadow(
                          color: widget.accentColor!.withValues(alpha: 0.30),
                          blurRadius: kGlowBlur,
                          spreadRadius: kGlowSpread,
                        ),
                      ]
                    : [],
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
