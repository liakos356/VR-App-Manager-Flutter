import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../utils/formatters.dart';
import '../utils/install_checker.dart';
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

class AppCardState extends State<AppCard> with WidgetsBindingObserver {
  bool _isHovered = false;
  int _currentImageIndex = 0;
  bool _isInstalled = false;
  String _installedPackageName = '';

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

  List<String> get _allImages {
    final images = <String>[];
    final hero =
        (widget.app['thumbnail_url'] ?? widget.app['preview_photo'])
            ?.toString();
    if (hero != null && hero.isNotEmpty) images.add(hero);
    if (widget.app['screenshots'] != null) {
      try {
        final decoded = jsonDecode(widget.app['screenshots'].toString());
        if (decoded is List) {
          images.addAll(
            decoded.map((e) => e.toString()).where((e) => e.isNotEmpty),
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
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeInOut)).animate(animation),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Legacy support: callers that pass isDetailView=true get AppDetailView.
    if (widget.isDetailView) {
      return AppDetailView(
          app: widget.app, apiUrl: widget.apiUrl, showAsPage: false);
    }

    final images = _allImages;
    final isOvrport = widget.app['ovrport'] == 1 ||
        widget.app['ovrport'] == true ||
        widget.app['ovrport'] == '1' ||
        widget.app['ovrport'] == 'true';

    final apkPath = widget.app['apk_path']?.toString().trim();
    final isUnavailable = apkPath == null || apkPath.isEmpty;

    return RepaintBoundary(
      child: Opacity(
        opacity: isUnavailable ? 0.70 : 1.0,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: _isHovered ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translateByDouble(0.0, -8.0 * t, 0.0, 1.0)
                ..scaleByDouble(1.0 + 0.03 * t, 1.0 + 0.03 * t, 1.0, 1.0),
              child: child,
            );
          },
          child: Card(
          elevation: _isHovered ? 18 : 6,
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: () => _showDetails(context),
            onLongPress: () => showInstallBottomSheet(
              context,
              app: widget.app,
              isInstalled: _isInstalled,
              installedPackageName: _installedPackageName,
              onInstallDone: _refreshInstallState,
            ),
            splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            highlightColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Image carousel ─────────────────────────────────────
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
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
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(Icons.vrpano,
                                    size: 64, color: Colors.white54),
                              ),
                            ),
                      if (isOvrport)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Ovrport',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (isUnavailable)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[800]!.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Unavailable',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Info panel ─────────────────────────────────────────
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: AutoSizeText(
                                  widget.app['name'] ??
                                      widget.app['title'] ??
                                      'Unknown App',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  minFontSize: 12,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (getAppSize(widget.app) > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Size: ${formatBytes(getAppSize(widget.app))}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: AutoSizeText(
                                  (widget.app['genres'] ??
                                      widget.app['category'] ??
                                      '') as String,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  minFontSize: 10,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StarRating(
                              rating: parseRating(
                                widget.app['user_rating'] ??
                                    widget.app['rating'],
                              ),
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),      // TweenAnimationBuilder
      ),      // Opacity
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

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
        Image.network(
          images[currentIndex],
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: Colors.grey[800],
            child: const Center(
                child: Icon(Icons.vrpano, size: 64, color: Colors.white54)),
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
