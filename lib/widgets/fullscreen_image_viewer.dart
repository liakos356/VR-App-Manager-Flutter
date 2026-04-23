import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Full-screen image viewer pushed as a Navigator page.
///
/// Supports:
/// - Left/right arrow buttons to navigate between images.
/// - Swipe left/right gesture (works even when InteractiveViewer is present
///   because panning is disabled while the image is at 1× zoom).
/// - Double-tap to toggle between 1× and 2.5× zoom.
/// - Pinch-to-zoom.
class FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullscreenImageViewer> createState() => FullscreenImageViewerState();
}

class FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) =>
                _ZoomablePage(imageUrl: widget.imageUrls[index]),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _OverlayButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // Previous button
          if (_currentIndex > 0)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _OverlayButton(
                  icon: Icons.arrow_back_ios,
                  size: 60,
                  onTap: _previousPage,
                ),
              ),
            ),

          // Next button
          if (_currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _OverlayButton(
                  icon: Icons.arrow_forward_ios,
                  size: 60,
                  onTap: _nextPage,
                ),
              ),
            ),

          // Dot indicators
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.imageUrls.length, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentIndex == i ? 10 : 7,
                    height: _currentIndex == i ? 10 : 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == i ? Colors.white : Colors.white38,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single page inside the viewer.
///
/// Uses a [TransformationController] to track the current zoom level.
/// When the image is at 1× zoom, [InteractiveViewer.panEnabled] is `false`
/// so the parent [PageView] can intercept horizontal swipe gestures.
/// When zoomed in, panning is re-enabled so the user can move around.
class _ZoomablePage extends StatefulWidget {
  final String imageUrl;
  const _ZoomablePage({required this.imageUrl});

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final _transformationController = TransformationController();
  bool _isZoomed = false;

  static const double _zoomIn = 2.5;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_isZoomed) {
      // Reset to fit
      _transformationController.value = Matrix4.identity();
    } else {
      // Zoom into the tapped point
      final pos = details.localPosition;
      final x = -pos.dx * (_zoomIn - 1);
      final y = -pos.dy * (_zoomIn - 1);
      _transformationController.value = Matrix4.identity()
        ..scale(_zoomIn)
        ..translate(x / _zoomIn, y / _zoomIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {}, // required so onDoubleTapDown fires
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 6.0,
        // Disable pan when not zoomed so PageView receives horizontal swipes
        panEnabled: _isZoomed,
        clipBehavior: Clip.none,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => const Center(
            child: Icon(Icons.broken_image, size: 100, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _OverlayButton({
    required this.icon,
    required this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}
