import 'dart:convert';
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/download_jobs_notifier.dart';
import '../services/download_service.dart';
import '../services/google_drive_service.dart';
import '../services/store_favorites_service.dart';
import '../utils/formatters.dart';
import '../utils/install_checker.dart';
import '../utils/localization.dart';
import '../utils/spatial_theme.dart';
import 'app_detail_view.dart';
import 'install_bottom_sheet.dart';
import 'star_rating.dart';

/// Displays a VR app as a compact grid card.
///
/// Tapping opens [AppDetailView] as a full-screen page.
/// Long-pressing opens the quick-install bottom sheet.
class AppCard extends StatefulWidget {
  final dynamic app;
  final String apiUrl;

  // TODO(legacy): isDetailView is no longer used; callers should migrate to
  // AppDetailView directly.  Kept here to avoid breaking existing call-sites.
  final bool isDetailView;

  const AppCard({
    super.key,
    required this.app,
    required this.apiUrl,
    this.isDetailView = false,
  });

  @override
  State<AppCard> createState() => AppCardState();
}

class AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  int _currentImageIndex = 0;
  bool _isInstalled = false;
  String _installedPackageName = '';
  String _installedVersion = '';
  late List<String> _cachedImages;
  late final AnimationController _flashController;
  late final Animation<double> _flashAnimation;
  bool _isQueueing = false;

  @override
  void initState() {
    super.initState();
    _cachedImages = _computeImages();
    _refreshInstallState();
    StoreFavoritesNotifier.instance.addListener(_onFavoritesChanged);
    DownloadJobsNotifier.instance.addListener(_onDownloadJobsChanged);
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _flashAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  void _onDownloadJobsChanged() {
    if (mounted) setState(() {});
  }

  bool _shouldShowDownloadButton() {
    final telegramUrl = widget.app['telegram_url']?.toString() ?? '';
    if (telegramUrl.isEmpty) return false;
    final dlPct = (widget.app['download_percentage'] as num?)?.toDouble() ?? 100.0;
    return dlPct < 100.0;
  }

  Future<void> _queueDownload() async {
    final appId = widget.app['id'];
    if (appId == null) return;
    setState(() => _isQueueing = true);
    try {
      await DownloadService().enqueue(appId is int ? appId : int.parse(appId.toString()));
      await DownloadJobsNotifier.instance.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Download queued!'))),
        );
      }
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
      if (mounted) setState(() => _isQueueing = false);
    }
  }

  @override
  void didUpdateWidget(AppCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app != widget.app) {
      _cachedImages = _computeImages();
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    StoreFavoritesNotifier.instance.removeListener(_onFavoritesChanged);
    DownloadJobsNotifier.instance.removeListener(_onDownloadJobsChanged);
    // Do NOT evict images from CachedNetworkImage's disk/memory cache here.
    // Evicting on dispose defeats the purpose of caching: images would need
    // to be re-downloaded every time a card re-enters the viewport while
    // scrolling.  Flutter's painting cache (limited in main.dart to 100 images
    // / 50 MB) handles LRU eviction automatically.
    super.dispose();
  }

  Future<void> _refreshInstallState() async {
    final result = await checkAppInstalled(widget.app);
    if (mounted) {
      setState(() {
        _isInstalled = result.isInstalled;
        _installedPackageName = result.packageName;
        _installedVersion = result.installedVersion;
      });
    }
  }

  List<String> _computeImages() {
    final images = <String>[];
    final hero = (widget.app['thumbnail_url'] ?? widget.app['preview_photo'])
        ?.toString();
    if (hero != null && hero.isNotEmpty) images.add(hero);
    if (widget.app['screenshots'] != null) {
      try {
        final decoded = jsonDecode(widget.app['screenshots'].toString());
        if (decoded is List) {
          images.addAll(
            decoded
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .take(
                  2,
                ), // limit to 2 screenshots on grid card to reduce memory
          );
        }
      } catch (_) {}
    }
    return images;
  }

  void _showDetails(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => AppDetailView(
          app: widget.app,
          apiUrl: widget.apiUrl,
          showAsPage: true,
        ),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuint,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Legacy support: callers that pass isDetailView=true get AppDetailView.
    if (widget.isDetailView) {
      return AppDetailView(
        app: widget.app,
        apiUrl: widget.apiUrl,
        showAsPage: false,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final images = _cachedImages;
    final isOvrport =
        widget.app['ovrport'] == 1 ||
        widget.app['ovrport'] == true ||
        widget.app['ovrport'] == '1' ||
        widget.app['ovrport'] == 'true';

    final apkPath = widget.app['apk_path']?.toString().trim();
    final isUnavailable = apkPath == null || apkPath.isEmpty;

    final dbVersion = widget.app['version']?.toString().trim() ?? '';
    final hasDriveUpdate =
        apkPath != null &&
        GoogleDriveService.isDrivePath(apkPath) &&
        _isInstalled &&
        dbVersion.isNotEmpty &&
        _installedVersion.isNotEmpty &&
        _installedVersion != dbVersion;

    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    final createdAt = DateTime.tryParse(
      widget.app['created_at']?.toString() ?? '',
    );
    final updatedAt = DateTime.tryParse(
      widget.app['updated_at']?.toString() ?? '',
    );
    final isNewApp = createdAt != null && createdAt.isAfter(oneWeekAgo);
    final isUpdatedApp =
        !isNewApp && updatedAt != null && updatedAt.isAfter(oneWeekAgo);

    return RepaintBoundary(
      child: Opacity(
        opacity: isUnavailable ? 0.62 : 1.0,
        // Hover lift + scale
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: _isHovered ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutQuint,
          builder: (context, t, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translateByDouble(0.0, -6.0 * t, 0.0, 1.0)
                ..scaleByDouble(1.0 + 0.05 * t, 1.0 + 0.05 * t, 1.0, 1.0),
              child: child,
            );
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showDetails(context),
              onLongPress: () => showInstallBottomSheet(
                context,
                app: widget.app,
                isInstalled: _isInstalled,
                installedPackageName: _installedPackageName,
                onInstallDone: _refreshInstallState,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kRadius),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutQuint,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: _isHovered
                              ? (isDark ? 0.55 : 0.22)
                              : (isDark ? 0.35 : 0.12),
                        ),
                        blurRadius: _isHovered ? 32 : 16,
                        spreadRadius: _isHovered ? 2 : -2,
                        offset: const Offset(0, 8),
                      ),
                      if (_isHovered)
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 24,
                          spreadRadius: 0,
                        ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── Full-bleed artwork ──────────────────────────────
                      images.isNotEmpty
                          ? _CardImageCarousel(
                              images: images,
                              currentIndex: _currentImageIndex,
                              isHovered: _isHovered,
                              hasMultiple: images.length > 1,
                              onPrev: () => setState(() {
                                _currentImageIndex =
                                    (_currentImageIndex - 1 + images.length) %
                                    images.length;
                              }),
                              onNext: () => setState(() {
                                _currentImageIndex =
                                    (_currentImageIndex + 1) % images.length;
                              }),
                            )
                          : Container(
                              color: isDark
                                  ? const Color(0xFF0D1420)
                                  : const Color(0xFFD0D8E8),
                              child: Center(
                                child: Icon(
                                  Icons.vrpano_outlined,
                                  size: 64,
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                            ),

                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(kRadius),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutQuint,
                              padding: const EdgeInsets.fromLTRB(10, 7, 10, 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.0),
                                    Colors.black.withValues(
                                      alpha: isDark ? 0.72 : 0.58,
                                    ),
                                  ],
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withValues(
                                      alpha: _isHovered ? 0.22 : 0.10,
                                    ),
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ── Status chips row ──────────────────
                                  if (isNewApp || isUpdatedApp || _isInstalled)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: [
                                          if (isNewApp)
                                            _SpatialBadge(
                                              label: 'New',
                                              accent: Colors.amber,
                                              isActive: true,
                                            ),
                                          if (isUpdatedApp)
                                            _SpatialBadge(
                                              label: 'Updated',
                                              accent: kMetaBlue,
                                              isActive: true,
                                            ),
                                          if (_isInstalled)
                                            _SpatialBadge(
                                              label: 'Installed',
                                              accent: Colors.green,
                                              isActive: true,
                                            ),
                                        ],
                                      ),
                                    ),
                                  // ── Title + favorite star ─────────────
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: AutoSizeText(
                                          widget.app['name'] ??
                                              widget.app['title'] ??
                                              'Unknown App',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black54,
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          minFontSize: 9,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      _FavoriteStarButton(
                                        appId: widget.app['id']?.toString() ??
                                            '',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // ── Genre + stars + size ──────────────
                                  Row(
                                    children: [
                                      Flexible(
                                        child: _SpatialBadge(
                                          label: (widget.app['genres'] ??
                                                  widget.app['category'] ??
                                                  '')
                                              as String,
                                          accent: accent,
                                          isActive: true,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      StarRating(
                                        rating: parseRating(
                                          widget.app['user_rating'] ??
                                              widget.app['rating'],
                                        ),
                                        size: 12,
                                      ),
                                      if (getAppSize(widget.app) > 0) ...[
                                        const SizedBox(width: 5),
                                        Text(
                                          formatBytes(getAppSize(widget.app)),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white.withValues(
                                              alpha: 0.55,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── 1px light-catch border (brightens on hover) ─────
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutQuint,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(kRadius),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(
                                  alpha: _isHovered ? 0.28 : 0.14,
                                ),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.5],
                            ),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(kRadius),
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: _isHovered ? 0.28 : 0.12,
                                ),
                                width: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Ovrport badge ───────────────────────────────────
                      if (isOvrport)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _SpatialBadge(
                            label: 'Ovrport',
                            accent: Colors.deepOrange,
                            isActive: true,
                          ),
                        ),

                      // ── Drive update chip ───────────────────────────────
                      if (hasDriveUpdate)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => showInstallBottomSheet(
                              context,
                              app: widget.app,
                              isInstalled: _isInstalled,
                              installedPackageName: _installedPackageName,
                              onInstallDone: _refreshInstallState,
                            ),
                            child: AnimatedBuilder(
                              animation: _flashAnimation,
                              builder: (context, child) => Opacity(
                                opacity: _flashAnimation.value,
                                child: child,
                              ),
                              child: _SpatialBadge(
                                label: 'UPDATE',
                                accent: Colors.red,
                                isActive: true,
                                glow: true,
                              ),
                            ),
                          ),
                        ),

                      // ── Unavailable badge ───────────────────────────────
                      if (isUnavailable)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _SpatialBadge(
                            label: 'Unavailable',
                            accent: Colors.grey,
                            isActive: false,
                          ),
                        ),

                      // ── Telegram download button ────────────────────────
                      if (_shouldShowDownloadButton())
                        Positioned(
                          top: isUnavailable ? 42 : 10,
                          left: 10,
                          child: _isQueueing
                              ? Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF229ED9),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(5),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _queueDownload,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF229ED9),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF229ED9)
                                              .withValues(alpha: 0.50),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.downloading,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ── Private helpers ───────────────────────────────────────────────────────────


/// Small star button that reflects and toggles the favorite state for [appId].
class _FavoriteStarButton extends StatelessWidget {
  final String appId;
  const _FavoriteStarButton({required this.appId});

  @override
  Widget build(BuildContext context) {
    if (appId.isEmpty) return const SizedBox.shrink();
    final isFav = StoreFavoritesNotifier.instance.isFavorite(appId);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => StoreFavoritesNotifier.instance.toggle(appId),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutQuint,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isFav
                  ? Colors.amber.withValues(alpha: 0.80)
                  : Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(
                color: isFav
                    ? Colors.amber.withValues(alpha: 0.80)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: isFav
                  ? [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.50),
                        blurRadius: 8,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              isFav ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isFav ? Colors.white : Colors.white70,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill/capsule-shaped status badge with optional glow.
class _SpatialBadge extends StatelessWidget {
  final String label;
  final Color accent;
  final bool isActive;
  final bool glow;

  const _SpatialBadge({
    required this.label,
    required this.accent,
    this.isActive = false,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isActive
                ? accent.withValues(alpha: 0.78)
                : Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive
                  ? accent.withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.55),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Image strip with hover-activated prev/next navigation and dot indicators.
class _CardImageCarousel extends StatelessWidget {
  final List<String> images;
  final int currentIndex;
  final bool isHovered;
  final bool hasMultiple;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _CardImageCarousel({
    required this.images,
    required this.currentIndex,
    required this.isHovered,
    required this.hasMultiple,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: images[currentIndex],
          fit: BoxFit.cover,
          memCacheWidth: 600,
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(Icons.vrpano, size: 64, color: Colors.white54),
            ),
          ),
        ),
        if (isHovered && hasMultiple) ...[
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navButton(icon: Icons.chevron_left, onPressed: onPrev),
                _navButton(icon: Icons.chevron_right, onPressed: onNext),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: currentIndex == i ? 8 : 6,
                  height: currentIndex == i ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentIndex == i ? Colors.white : Colors.white54,
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _navButton({required IconData icon, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 32),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black45,
        shape: const CircleBorder(),
      ),
    );
  }
}
