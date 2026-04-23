import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Plays any video URL (direct file, HLS, YouTube, etc.) inside a WebView
/// using an HTML5 <video> element.  This sidesteps ExoPlayer codec issues
/// by delegating playback to the system WebView / Chromium engine.
class VideoDialog extends StatefulWidget {
  final String videoUrl;
  const VideoDialog({super.key, required this.videoUrl});

  @override
  State<VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<VideoDialog> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _makeController(widget.videoUrl);
  }

  static WebViewController _makeController(String videoUrl) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (_) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse(videoUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: WebViewWidget.fromPlatformCreationParams(
                  params:
                      AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
                        PlatformWebViewWidgetCreationParams(
                          controller: _controller.platform,
                        ),
                        displayWithHybridComposition: true,
                      ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: _CircleOverlayButton(
                  icon: Icons.close,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: _CircleOverlayButton(
                  icon: Icons.fullscreen,
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) =>
                            _VideoFullscreenPage(videoUrl: widget.videoUrl),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Full-screen page ---------------------------------------------------------

class _VideoFullscreenPage extends StatefulWidget {
  final String videoUrl;
  const _VideoFullscreenPage({required this.videoUrl});

  @override
  State<_VideoFullscreenPage> createState() => _VideoFullscreenPageState();
}

class _VideoFullscreenPageState extends State<_VideoFullscreenPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _VideoDialogState._makeController(widget.videoUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          WebViewWidget.fromPlatformCreationParams(
            params:
                AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
                  PlatformWebViewWidgetCreationParams(
                    controller: _controller.platform,
                  ),
                  displayWithHybridComposition: true,
                ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _CircleOverlayButton(
              icon: Icons.close,
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.pop();
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _CircleOverlayButton(
              icon: Icons.fullscreen_exit,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

// -- Shared helper ------------------------------------------------------------

class _CircleOverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleOverlayButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
