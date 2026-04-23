import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../utils/localization.dart';
import 'trailer_dialog.dart';
import 'video_dialog.dart';

/// Large install / uninstall button with an animated progress bar overlay.
/// While a download is in progress, tapping the button cancels it.
class AppDetailInstallButton extends StatelessWidget {
  final bool isInstalled;
  final bool isInstalling;
  final bool isAvailable;
  final double installProgress;
  final String installStatus;
  final VoidCallback? onTap;
  final bool compact;

  const AppDetailInstallButton({
    super.key,
    required this.isInstalled,
    required this.isInstalling,
    required this.isAvailable,
    required this.installProgress,
    required this.installStatus,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = !isAvailable
        ? (isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade300)
        : isInstalling
        ? Colors.grey.shade800
        : isInstalled
        ? Colors.red.shade600
        : Theme.of(context).colorScheme.primary;

    final contentColor = !isAvailable
        ? (isDark ? Colors.white30 : Colors.black26)
        : Theme.of(context).colorScheme.onPrimary;

    final label = !isAvailable
        ? tr('Unavailable')
        : isInstalling
        ? (installProgress > 0.0 && installProgress < 1.0
              ? '${(installProgress * 100).toInt()}%'
              : installStatus)
        : (isInstalled ? tr('Uninstall') : tr('Install'));

    final IconData icon = isInstalling
        ? Icons.stop_rounded
        : (isInstalled ? Icons.delete_outline : Icons.download);

    final double btnHeight = compact ? 48 : 64;
    final double hPad = compact ? 20 : 36;
    final double vPad = compact ? 12 : 18;
    final double iconSize = compact ? 20 : 24;
    final double fontSize = compact ? 15 : 18;

    return Container(
      height: btnHeight,
      constraints: BoxConstraints(minWidth: compact ? 120 : 180),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
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
                padding: EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: vPad,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: iconSize, color: contentColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: contentColor,
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
  final bool compact;
  const AppDetailTrailerButton({super.key, required this.videoUrl, this.compact = false});

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
      icon: Icon(Icons.play_circle_fill, size: compact ? 20 : 24),
      label: Text(
        tr('Watch Trailer'),
        style: TextStyle(fontSize: compact ? 15 : 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 28, vertical: compact ? 12 : 18),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(compact ? 12 : 16)),
      ),
    );
  }
}
