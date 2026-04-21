import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:installed_apps/installed_apps.dart';

import '../install_service.dart';
import '../utils/formatters.dart';
import '../utils/install_checker.dart';
import '../utils/installed_apps_cache.dart';
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

  // Cached derived fields — updated in initState/didUpdateWidget.
  List<String> _screenshots = [];
  List<String> _tags = [];
  String _appName = '';
  String? _heroUrl;
  String? _videoUrl;
  String _genre = '';
  double _rating = 0.0;
  bool _isOvrport = false;

  @override
  void initState() {
    super.initState();
    _updateDerivedFields();
    WidgetsBinding.instance.addObserver(this);
    _refreshInstallState();
  }

  @override
  void didUpdateWidget(AppDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app != widget.app) {
      _updateDerivedFields();
      _refreshInstallState();
    }
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
          InstalledAppsCache.invalidate();
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
        apkPath: widget.app['apk_path']?.toString() ?? '',
        obbDir: widget.app['obb_dir']?.toString() ?? '',
        onProgress: (s) => setState(() => _installStatus = s),
        onDownloadProgress: (p) {
          if (p >= 0.0 && p <= 1.0) setState(() => _installProgress = p);
        },
      );
      InstalledAppsCache.invalidate();
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

  /// Recomputes all derived values from [widget.app].
  /// Called once in [initState] and again in [didUpdateWidget] when the app changes.
  void _updateDerivedFields() {
    _screenshots = _parseStringList(widget.app['screenshots']);
    _tags = _parseStringList(widget.app['tags']);
    _appName = widget.app['name'] ?? widget.app['title'] ?? 'Unknown App';
    _heroUrl = (widget.app['thumbnail_url'] ?? widget.app['preview_photo'])
        ?.toString();
    _videoUrl = (widget.app['trailer_url'] ?? widget.app['video_url'])
        ?.toString();
    _genre = (widget.app['genres'] ?? widget.app['category'] ?? '').toString();
    _rating = parseRating(widget.app['user_rating'] ?? widget.app['rating']);
    _isOvrport =
        widget.app['ovrport'] == 1 ||
        widget.app['ovrport'] == true ||
        widget.app['ovrport'] == '1' ||
        widget.app['ovrport'] == 'true';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAsPage) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(_appName),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _buildWideBody(context),
      );
    }
    return _buildPanelBody(context);
  }

  // ── Full-screen two-column layout (used when pushed as a page) ────────────

  Widget _buildWideBody(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: hero image + screenshots
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppDetailHeroImage(url: _heroUrl),
                if (_screenshots.isNotEmpty) ...[
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
                          screenshots: _screenshots,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right: metadata + install
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _appName,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 32,
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
                                      fontSize: 16,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppDetailInstallButton(
                          isInstalled: _isInstalled,
                          isInstalling: _isInstalling,
                          isAvailable: (widget.app['apk_path']?.toString().trim().isNotEmpty ?? false),
                          installProgress: _installProgress,
                          installStatus: _installStatus,
                          onTap: _isInstalling || (widget.app['apk_path']?.toString().trim().isEmpty ?? true) ? null : _handleInstallTap,
                        ),
                        if (_videoUrl != null && _videoUrl!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          AppDetailTrailerButton(videoUrl: _videoUrl!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BadgeChip(
                        label: _genre.isEmpty ? 'Category' : _genre,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      RatingRow(isOvrport: _isOvrport, rating: _rating),
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        TagChips(tags: _tags),
                      ],
                      const SizedBox(height: 40),
                      Text(
                        tr('Description'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DescriptionBox(app: widget.app),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Compact single-column layout (used inside the split panel) ────────────

  Widget _buildPanelBody(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image — full width, compact height
          AppDetailHeroImage(url: _heroUrl, height: 200),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  _appName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (getAppSize(widget.app) > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${formatBytes(getAppSize(widget.app))}'
                    '${getObbSize(widget.app) > 0 ? '  (APK: ${formatBytes(getApkSize(widget.app))} + OBB: ${formatBytes(getObbSize(widget.app))})' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Action buttons — side by side
                Row(
                  children: [
                    Expanded(
                      child: AppDetailInstallButton(
                        isInstalled: _isInstalled,
                        isInstalling: _isInstalling,
                        isAvailable: (widget.app['apk_path']?.toString().trim().isNotEmpty ?? false),
                        installProgress: _installProgress,
                        installStatus: _installStatus,
                        onTap: _isInstalling || (widget.app['apk_path']?.toString().trim().isEmpty ?? true) ? null : _handleInstallTap,
                        compact: true,
                      ),
                    ),
                    if (_videoUrl != null && _videoUrl!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppDetailTrailerButton(
                          videoUrl: _videoUrl!,
                          compact: true,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Genre + rating + tags
                BadgeChip(
                  label: _genre.isEmpty ? 'Category' : _genre,
                  color: Theme.of(context).colorScheme.primary,
                ),
                RatingRow(isOvrport: _isOvrport, rating: _rating),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TagChips(tags: _tags),
                ],
                const SizedBox(height: 20),

                // Description
                Text(
                  tr('Description'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _DescriptionBox(app: widget.app),

                // Screenshots
                if (_screenshots.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    tr('Screenshots'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: AppDetailScreenshotGrid(screenshots: _screenshots),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
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
