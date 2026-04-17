import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../utils/localization.dart';
import 'trailer_dialog.dart';
import 'video_dialog.dart';

/// Large install / uninstall button with an animated progress bar overlay.
class AppDetailInstallButton extends StatelessWidget {
  final bool isInstalled;
  final bool isInstalling;
  final double installProgress;
  final String installStatus;
  final VoidCallback? onTap;

  const AppDetailInstallButton({
    super.key,
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

/// Button that opens the YouTube trailer or a generic video dialog.
class AppDetailTrailerButton extends StatelessWidget {
  final String videoUrl;
  const AppDetailTrailerButton({super.key, required this.videoUrl});

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
            builder: (context) => TrailerDialog(videoId: videoId),
          );
        } else if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => VideoDialog(videoUrl: url),
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
