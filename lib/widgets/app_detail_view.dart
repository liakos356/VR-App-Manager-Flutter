import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:installed_apps/installed_apps.dart';

import '../install_service.dart';
import '../utils/formatters.dart';
import '../utils/install_checker.dart';
import '../utils/localization.dart';
import 'app_detail_actions.dart';
import 'app_detail_media.dart';
import 'badge_chip.dart';

/// Full detail view for a VR app.
///
/// When [showAsPage] is `true` the widget renders inside a [Scaffold] with an
/// AppBar and back button (used when pushed as a navigation route).
/// When `false` it returns the bare content (used inside the split-panel).
class AppDetailView extends StatefulWidget {
  final dynamic app;
  final String apiUrl;
  final bool showAsPage;

  const AppDetailView({
    super.key,
    required this.app,
    required this.apiUrl,
    this.showAsPage = false,
  });

  @override
  State<AppDetailView> createState() => _AppDetailViewState();
}

class _AppDetailViewState extends State<AppDetailView>
    with WidgetsBindingObserver {
  bool _isInstalled = false;
  String _installedPackageName = '';
  bool _isInstalling = false;
  double _installProgress = 0.0;
  String _installStatus = 'Starting...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshInstallState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshInstallState();
  }

  Future<void> _refreshInstallState() async {
    final result = await checkAppInstalled(widget.app);
    if (mounted) {
      setState(() {
        _isInstalled = result.isInstalled;
        _installedPackageName = result.packageName;
      });
    }
  }

  Future<void> _handleInstallTap() async {
    if (_isInstalled) {
      if (_installedPackageName.isNotEmpty) {
        try {
          await InstalledApps.uninstallApp(_installedPackageName);
          await Future.delayed(const Duration(seconds: 1));
          _refreshInstallState();
        } catch (_) {}
      }
      return;
    }

    final String appId = widget.app['id']?.toString() ?? '';
    if (appId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Invalid Object: App ID is empty')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isInstalling = true;
      _installProgress = 0.0;
      _installStatus = 'Starting...';
    });

    try {
      await InstallService.installAppLocally(
        appId: appId,
        apkPath: widget.app['file_path_apk']?.toString() ?? '',
        obbDir: widget.app['file_path_obb']?.toString() ?? '',
        onProgress: (s) => setState(() => _installStatus = s),
        onDownloadProgress: (p) {
          if (p >= 0.0 && p <= 1.0) setState(() => _installProgress = p);
        },
      );
      setState(() {
        _isInstalling = false;
        _installProgress = 1.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Installation Completed!')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isInstalling = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Parses a JSON-encoded or comma-separated list field into plain strings.
  List<String> _parseStringList(dynamic raw) {
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return raw
        .toString()
        .replaceAll(RegExp(r'[\[\]"]'), '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenshots = _parseStringList(widget.app['screenshots']);
    final tags = _parseStringList(widget.app['tags']);
    final appName = widget.app['name'] ?? widget.app['title'] ?? 'Unknown App';
    final heroUrl = (widget.app['thumbnail_url'] ?? widget.app['preview_photo'])
        ?.toString();
    final videoUrl = (widget.app['trailer_url'] ?? widget.app['video_url'])
        ?.toString();
    final genre = (widget.app['genres'] ?? widget.app['category'] ?? '')
        .toString();
    final rating = parseRating(
      widget.app['user_rating'] ?? widget.app['rating'],
    );
    final isOvrport =
        widget.app['ovrport'] == 1 ||
        widget.app['ovrport'] == true ||
        widget.app['ovrport'] == '1' ||
        widget.app['ovrport'] == 'true';

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: hero image + screenshots ──────────────────────────────────
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppDetailHeroImage(url: heroUrl),
                if (screenshots.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      tr('Screenshots'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: AppDetailScreenshotGrid(
                          screenshots: screenshots,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Right: metadata + install ────────────────────────────────────────
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 40, 40, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + size
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appName,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: getAppSize(widget.app) > 0
                                ? Text(
                                    'Size: ${formatBytes(getAppSize(widget.app))}'
                                    '${getObbSize(widget.app) > 0 ? '\n(APK: ${formatBytes(getApkSize(widget.app))} + OBB: ${formatBytes(getObbSize(widget.app))})' : ''}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.7),
                                    ),
                                  )
                                : const SizedBox(height: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Install button + trailer
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppDetailInstallButton(
                          isInstalled: _isInstalled,
                          isInstalling: _isInstalling,
                          installProgress: _installProgress,
                          installStatus: _installStatus,
                          onTap: _isInstalling ? null : _handleInstallTap,
                        ),
                        if (videoUrl != null && videoUrl.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          AppDetailTrailerButton(videoUrl: videoUrl),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable metadata
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Genre badge
                      BadgeChip(
                        label: genre.isEmpty ? 'Category' : genre,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      // Ovrport + rating row
                      RatingRow(isOvrport: isOvrport, rating: rating),
                      // Tags
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        TagChips(tags: tags),
                      ],
                      const SizedBox(height: 48),
                      Text(
                        tr('Description'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DescriptionBox(app: widget.app), // stays local
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.showAsPage) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(appName),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: body,
      );
    }
    return body;
  }
}

// ── Private helper widget (only used in this file) ────────────────────────────

class _DescriptionBox extends StatelessWidget {
  final dynamic app;
  const _DescriptionBox({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: isGreekNotifier,
        builder: (context, isGreek, _) {
          final desc = isGreek
              ? (app['long_description_gr'] ??
                    app['long_description'] ??
                    app['description'] ??
                    'No description available.')
              : (app['long_description'] ??
                    app['description'] ??
                    'No description available.');
          if (desc.toString().toLowerCase().contains('<')) {
            return Html(data: desc.toString());
          }
          return Text(
            desc.toString(),
            style: TextStyle(
              fontSize: 18,
              height: 1.6,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
            ),
          );
        },
      ),
    );
  }
}
