import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Image strip with hover-activated prev/next navigation and dot indicators.
///
/// Used inside [AppCard] to cycle through a VR app's cover images.
class CardImageCarousel extends StatelessWidget {
  final List<String> images;
  final int currentIndex;
  final bool isHovered;
  final bool hasMultiple;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const CardImageCarousel({
    super.key,
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
