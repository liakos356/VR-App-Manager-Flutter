import 'package:flutter/material.dart';

import 'fullscreen_image_viewer.dart';

/// Hero banner image for the app detail view.
class AppDetailHeroImage extends StatelessWidget {
  final String? url;
  final double height;
  const AppDetailHeroImage({super.key, this.url, this.height = 350});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url!,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    width: double.infinity,
    height: height,
    decoration: BoxDecoration(
      color: Colors.grey[800],
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(
      child: Icon(Icons.vrpano, size: 80, color: Colors.white54),
    ),
  );
}

/// Grid of screenshot thumbnails; tapping opens a fullscreen viewer.
class AppDetailScreenshotGrid extends StatelessWidget {
  final List<String> screenshots;
  const AppDetailScreenshotGrid({super.key, required this.screenshots});

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
            builder: (context) => FullscreenImageViewer(
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
              loadingBuilder: (context, child, progress) {
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
              errorBuilder: (context, error, stackTrace) => Container(
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
