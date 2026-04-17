import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../install_service.dart';
import '../utils/formatters.dart';
import '../utils/install_checker.dart';
import '../utils/localization.dart';
import 'fullscreen_image_viewer.dart';
import 'star_rating.dart';
import 'trailer_dialog.dart';
import 'video_dialog.dart';

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
                _HeroImage(url: heroUrl),
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
                        child: _ScreenshotGrid(screenshots: screenshots),
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
                        _InstallButton(
                          isInstalled: _isInstalled,
                          isInstalling: _isInstalling,
                          installProgress: _installProgress,
                          installStatus: _installStatus,
                          onTap: _isInstalling ? null : _handleInstallTap,
                        ),
                        if (videoUrl != null && videoUrl.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _TrailerButton(videoUrl: videoUrl),
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
                      _BadgeChip(
                        label: genre.isEmpty ? 'Category' : genre,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      // Ovrport + rating row
                      _RatingRow(isOvrport: isOvrport, rating: rating),
                      // Tags
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _TagChips(tags: tags),
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

// ── Private helper widgets ────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  final String? url;
  const _HeroImage({this.url});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url!,
          width: double.infinity,
          height: 350,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    width: double.infinity,
    height: 350,
    decoration: BoxDecoration(
      color: Colors.grey[800],
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(
      child: Icon(Icons.vrpano, size: 80, color: Colors.white54),
    ),
  );
}

class _ScreenshotGrid extends StatelessWidget {
  final List<String> screenshots;
  const _ScreenshotGrid({required this.screenshots});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor = isDark ? Colors.grey[800] : Colors.grey[300];
    final iconColor = isDark ? Colors.white54 : Colors.black54;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: List.generate(screenshots.length, (index) {
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => FullscreenImageViewer(
              imageUrls: screenshots,
              initialIndex: index,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              screenshots[index],
              width: 200,
              height: 150,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 200,
                  height: 150,
                  color: placeholderColor,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Container(
                width: 200,
                height: 150,
                color: placeholderColor,
                child: Center(
                  child: Icon(Icons.broken_image, color: iconColor),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _InstallButton extends StatelessWidget {
  final bool isInstalled;
  final bool isInstalling;
  final double installProgress;
  final String installStatus;
  final VoidCallback? onTap;

  const _InstallButton({
    required this.isInstalled,
    required this.isInstalling,
    required this.installProgress,
    required this.installStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isInstalling
        ? Colors.grey.shade800
        : (isInstalled
              ? Colors.red.shade600
              : Theme.of(context).colorScheme.primary);

    final label = isInstalling
        ? (installProgress > 0.0 && installProgress < 1.0
              ? '${(installProgress * 100).toInt()}%'
              : installStatus)
        : (isInstalled ? tr('Uninstall') : tr('Install'));

    return Container(
      height: 72,
      constraints: const BoxConstraints(minWidth: 200),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isInstalling)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: installProgress.clamp(0.0, 1.0),
                  child: Container(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 24,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isInstalling ? Icons.downloading : Icons.download,
                      size: 28,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailerButton extends StatelessWidget {
  final String videoUrl;
  const _TrailerButton({required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        String url = videoUrl;
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://$url';
        }
        final videoId = YoutubePlayerController.convertUrlToId(url);
        if (videoId != null && context.mounted) {
          showDialog(
            context: context,
            builder: (_) => TrailerDialog(videoId: videoId),
          );
        } else if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => VideoDialog(videoUrl: url),
          );
        }
      },
      icon: const Icon(Icons.play_circle_fill, size: 28),
      label: Text(
        tr('Watch Trailer'),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// A rounded badge/chip used for genre and ovrport labels.
class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;

  const _BadgeChip({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

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

// ── Rating + ovrport badge row ────────────────────────────────────────────────

class _RatingRow extends StatelessWidget {
  final bool isOvrport;
  final double rating;

  const _RatingRow({required this.isOvrport, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isOvrport)
          Padding(
            padding: const EdgeInsets.only(top: 12.0, right: 12.0),
            child: _BadgeChip(
              label: 'Ovrport',
              color: Colors.orange,
              outlined: true,
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              children: [
                StarRating(rating: rating, size: 32),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${rating.toStringAsFixed(1).replaceAll('.0', '')}/5',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tag chips row ─────────────────────────────────────────────────────────────

class _TagChips extends StatelessWidget {
  final List<String> tags;
  const _TagChips({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        );
      }).toList(),
    );
  }
}
