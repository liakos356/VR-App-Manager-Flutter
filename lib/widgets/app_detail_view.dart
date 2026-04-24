import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:installed_apps/installed_apps.dart';

import '../install_service.dart';
import '../services/download_jobs_notifier.dart';
import '../services/download_service.dart';
import '../services/store_favorites_service.dart';
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
  bool _isCancelled = false;
  double _installProgress = 0.0;
  String _installStatus = 'Starting...';

  // ── Download queue state ──────────────────────────────────────────────────
  Map<String, dynamic>? _dlJob;
  bool _dlLoading = false;
  Timer? _dlPollTimer;

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
    StoreFavoritesNotifier.instance.addListener(_onFavoritesChanged);
    _refreshInstallState();
    _refreshDlJob();
  }

  @override
  void didUpdateWidget(AppDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app != widget.app) {
      _updateDerivedFields();
      _refreshInstallState();
      _refreshDlJob();
    }
  }

  @override
  void dispose() {
    StoreFavoritesNotifier.instance.removeListener(_onFavoritesChanged);
    WidgetsBinding.instance.removeObserver(this);
    _dlPollTimer?.cancel();
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  // ── Download job helpers ─────────────────────────────────────────────────

  Future<void> _refreshDlJob() async {
    final appId = widget.app['id'];
    if (appId == null) return;
    final int id = appId is int ? appId : int.tryParse(appId.toString()) ?? -1;
    if (id < 0) return;
    try {
      final jobs = await DownloadService().listJobs();
      final match = jobs.where((j) {
        final jId = j['app_id'] ?? j['apps']?['id'];
        return jId == id;
      }).toList();
      if (!mounted) return;
      setState(() => _dlJob = match.isNotEmpty ? match.first : null);
      // If there's an active job, start polling; otherwise stop.
      final isActive = _isActiveJob(_dlJob);
      if (isActive && _dlPollTimer == null) {
        _dlPollTimer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => _refreshDlJob(),
        );
      } else if (!isActive) {
        _dlPollTimer?.cancel();
        _dlPollTimer = null;
        if (_dlJob?['status'] == 'done') {
          _refreshInstallState();
        }
      }
    } catch (_) {}
  }

  bool _isActiveJob(Map<String, dynamic>? job) {
    final s = job?['status']?.toString();
    return s == 'queued' ||
        s == 'downloading' ||
        s == 'extracting' ||
        s == 'uploading';
  }

  Future<void> _enqueueDownload() async {
    final appId = widget.app['id'];
    if (appId == null) return;
    final int id = appId is int ? appId : int.tryParse(appId.toString()) ?? -1;
    if (id < 0) return;
    setState(() => _dlLoading = true);
    try {
      await DownloadService().enqueue(id);
      await DownloadJobsNotifier.instance.refresh();
      await _refreshDlJob();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('Error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dlLoading = false);
    }
  }

  Future<void> _cancelDlJob() async {
    final jobId = _dlJob?['id'] as int?;
    if (jobId == null) return;
    try {
      await DownloadService().cancelOrDelete(jobId);
      await DownloadJobsNotifier.instance.refresh();
      await _refreshDlJob();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('Error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      _isCancelled = false;
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
        isCancelled: () => _isCancelled,
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
      if (mounted && !_isCancelled) {
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
    final appId = widget.app['id']?.toString() ?? '';
    final isFav = StoreFavoritesNotifier.instance.isFavorite(appId);
    if (widget.showAsPage) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(_appName),
          actions: [
            if (appId.isNotEmpty)
              IconButton(
                tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFav ? Colors.amber : null,
                ),
                onPressed: () => StoreFavoritesNotifier.instance.toggle(appId),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _buildWideBody(context),
      );
    }
    return _buildPanelBody(context, appId: appId, isFav: isFav);
  }

  // ── Full-screen two-column layout (used when pushed as a page) ────────────

  /// Builds the download section shown in the detail view.
  Widget _buildDownloadSection(BuildContext context) {
    final dlPct =
        (widget.app['download_percentage'] as num?)?.toDouble() ?? 100.0;
    final telegramUrl = widget.app['telegram_url']?.toString() ?? '';
    final apkReady =
        widget.app['apk_path']?.toString().trim().isNotEmpty == true;

    // Nothing to show if the app is fully available and no active job.
    if (dlPct >= 100 && _dlJob == null && apkReady)
      return const SizedBox.shrink();

    final jobStatus = _dlJob?['status']?.toString();
    final jobProgress = (_dlJob?['progress'] as num?)?.toDouble() ?? 0.0;
    final jobStep = _dlJob?['step']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Drive Download'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),

          // No job yet
          if (_dlJob == null) ...[
            if (dlPct < 100 && telegramUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _dlLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.downloading, size: 18),
                  label: Text(tr('Queue Download (Telegram \u2192 Drive)')),
                  onPressed: _dlLoading ? null : _enqueueDownload,
                ),
              )
            else
              Text(
                tr('No download job active'),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ]
          // Active job
          else if (_isActiveJob(_dlJob)) ...[
            Row(
              children: [
                _StatusChipSmall(status: jobStatus ?? ''),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: Text(tr('Cancel')),
                  onPressed: _cancelDlJob,
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: jobProgress / 100.0,
              backgroundColor: Colors.grey.shade700,
            ),
            const SizedBox(height: 4),
            Text(
              jobStep.isNotEmpty
                  ? '$jobStep \u00b7 ${jobProgress.toStringAsFixed(0)}%'
                  : '${jobProgress.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]
          // Done
          else if (jobStatus == 'done') ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr('Ready \u2014 tap Install to continue'),
                    style: const TextStyle(color: Colors.green, fontSize: 13),
                  ),
                ),
              ],
            ),
          ]
          // Error
          else if (jobStatus == 'error') ...[
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _dlJob?['error']?.toString() ?? tr('Download failed'),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _enqueueDownload,
                  child: Text(tr('Retry')),
                ),
              ],
            ),
          ]
          // Cancelled or other finished states
          else ...[
            Text(
              tr('Download ${jobStatus ?? 'unknown'}'),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (telegramUrl.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.downloading, size: 16),
                label: Text(tr('Re-queue')),
                onPressed: _enqueueDownload,
              ),
          ],
        ],
      ),
    );
  }

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
                    IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppDetailInstallButton(
                            isInstalled: _isInstalled,
                            isInstalling: _isInstalling,
                            isAvailable:
                                (widget.app['apk_path']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ??
                                false),
                            installProgress: _installProgress,
                            installStatus: _installStatus,
                            onTap:
                                (widget.app['apk_path']
                                        ?.toString()
                                        .trim()
                                        .isEmpty ??
                                    true)
                                ? null
                                : (_isInstalling
                                      ? () =>
                                            setState(() => _isCancelled = true)
                                      : _handleInstallTap),
                            compact: true,
                          ),
                          if (_isInstalled &&
                              _installedPackageName.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            AppDetailLaunchButton(
                              packageName: _installedPackageName,
                              compact: true,
                            ),
                          ],
                          if (_videoUrl != null && _videoUrl!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            AppDetailTrailerButton(
                              videoUrl: _videoUrl!,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
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
                      const SizedBox(height: 16),
                      _buildDownloadSection(context),
                      const SizedBox(height: 24),
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

  Widget _buildPanelBody(
    BuildContext context, {
    required String appId,
    required bool isFav,
  }) {
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
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Action buttons
                if (_videoUrl != null && _videoUrl!.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column: Watch Trailer
                      Expanded(
                        child: AppDetailTrailerButton(
                          videoUrl: _videoUrl!,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right column: Install/Uninstall + Launch
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AppDetailInstallButton(
                                    isInstalled: _isInstalled,
                                    isInstalling: _isInstalling,
                                    isAvailable:
                                        (widget.app['apk_path']
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ??
                                        false),
                                    installProgress: _installProgress,
                                    installStatus: _installStatus,
                                    onTap:
                                        (widget.app['apk_path']
                                                ?.toString()
                                                .trim()
                                                .isEmpty ??
                                            true)
                                        ? null
                                        : (_isInstalling
                                              ? () => setState(
                                                  () => _isCancelled = true,
                                                )
                                              : _handleInstallTap),
                                    compact: true,
                                  ),
                                ),
                                if (appId.isNotEmpty)
                                  IconButton(
                                    tooltip: isFav
                                        ? 'Remove from favorites'
                                        : 'Add to favorites',
                                    icon: Icon(
                                      isFav
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: isFav ? Colors.amber : null,
                                    ),
                                    onPressed: () => StoreFavoritesNotifier
                                        .instance
                                        .toggle(appId),
                                  ),
                              ],
                            ),
                            if (_isInstalled &&
                                _installedPackageName.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              AppDetailLaunchButton(
                                packageName: _installedPackageName,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppDetailInstallButton(
                              isInstalled: _isInstalled,
                              isInstalling: _isInstalling,
                              isAvailable:
                                  (widget.app['apk_path']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ??
                                  false),
                              installProgress: _installProgress,
                              installStatus: _installStatus,
                              onTap:
                                  (widget.app['apk_path']
                                          ?.toString()
                                          .trim()
                                          .isEmpty ??
                                      true)
                                  ? null
                                  : (_isInstalling
                                        ? () => setState(
                                            () => _isCancelled = true,
                                          )
                                        : _handleInstallTap),
                              compact: true,
                            ),
                          ),
                          if (appId.isNotEmpty)
                            IconButton(
                              tooltip: isFav
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                              icon: Icon(
                                isFav
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: isFav ? Colors.amber : null,
                              ),
                              onPressed: () =>
                                  StoreFavoritesNotifier.instance.toggle(appId),
                            ),
                        ],
                      ),
                      if (_isInstalled && _installedPackageName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        AppDetailLaunchButton(
                          packageName: _installedPackageName,
                          compact: true,
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
                const SizedBox(height: 12),

                // Download section
                _buildDownloadSection(context),

                const SizedBox(height: 8),

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

class _StatusChipSmall extends StatelessWidget {
  final String status;
  const _StatusChipSmall({required this.status});

  Color _color() {
    switch (status) {
      case 'downloading':
        return const Color(0xFF229ED9);
      case 'extracting':
        return const Color(0xFFF0A500);
      case 'uploading':
        return const Color(0xFFBC8CFF);
      case 'done':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.bold),
      ),
    );
  }
}
