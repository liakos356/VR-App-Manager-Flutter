import 'package:flutter/material.dart';

import '../utils/localization.dart';

/// A single row in the master-detail list panel.
///
/// Displays a thumbnail, title, and short description for one VR app.
class AppListTile extends StatelessWidget {
  final dynamic app;
  final bool isSelected;
  final String apiUrl;
  final VoidCallback onTap;

  const AppListTile({
    super.key,
    required this.app,
    required this.isSelected,
    required this.apiUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGreek = isGreekNotifier.value;
    final desc = isGreek
        ? (app['short_description_gr'] ?? app['description'] ?? '')
        : (app['short_description'] ?? app['description'] ?? '');
    final imgUrl = app['thumbnail_url'] ?? app['preview_photo'];
    final apkPath = app['apk_path']?.toString().trim();
    final isUnavailable = apkPath == null || apkPath.isEmpty;

    final Widget leadingImage;
    if (app['image'] != null) {
      leadingImage = Image.network(
        '$apiUrl/files/image?path=${Uri.encodeComponent(app['image'])}',
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else if (imgUrl != null) {
      leadingImage = Image.network(
        imgUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else {
      leadingImage = _placeholder();
    }

    return Opacity(
      opacity: isUnavailable ? 0.70 : 1.0,
      child: ListTile(
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withAlpha(25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: leadingImage,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              app['name'] ?? app['title'] ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
          if (isUnavailable)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[700],
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
        ],
      ),
      subtitle: Text(
        desc,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      onTap: onTap,
      ),
    );
  }

  static Widget _placeholder() => Container(
    width: 64,
    height: 64,
    color: Colors.grey.withAlpha(51),
    child: const Icon(Icons.videogame_asset),
  );
}
