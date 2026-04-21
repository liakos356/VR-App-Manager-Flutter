import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Full-screen WebView that drives the Google OAuth 2.0 PKCE flow.
class OAuthWebViewScreen extends StatefulWidget {
  final String authUrl;

  const OAuthWebViewScreen({super.key, required this.authUrl});

  @override
  State<OAuthWebViewScreen> createState() => _OAuthWebViewScreenState();
}

class _OAuthWebViewScreenState extends State<OAuthWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _errorMessage;

  static const _callbackScheme =
      'com.googleusercontent.apps.1012473018198-r4fbunv4mq4mo0fegafkmqeoorllqr1v';

  // JS injected on every page-start to make the WebView look like Chrome.
  static const _chromeSpoofJs = '''
    (function() {
      if (!window.chrome) {
        Object.defineProperty(window, 'chrome', {
          value: {
            app: { isInstalled: false },
            runtime: {},
            loadTimes: function(){},
            csi: function(){},
            webstore: {}
          },
          configurable: true,
          writable: true
        });
      }
      try {
        Object.defineProperty(navigator, 'webdriver', { get: () => false });
      } catch(e) {}
    })();
  ''';

  @override
  void initState() {
    super.initState();
    debugPrint('[OAuthWebView] Loading URL: ${widget.authUrl}');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[OAuthWebView] Page started: $url');
            if (mounted) setState(() { _loading = true; _errorMessage = null; });
            _controller.runJavaScript(_chromeSpoofJs);
          },
          onPageFinished: (url) {
            debugPrint('[OAuthWebView] Page finished: $url');
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            debugPrint('[OAuthWebView] Navigation: ${request.url}');
            if (request.url.startsWith(_callbackScheme)) {
              final uri = Uri.parse(request.url);
              final code = uri.queryParameters['code'];
              final error = uri.queryParameters['error'];
              debugPrint('[OAuthWebView] Callback — code:${code != null} error:$error');
              if (mounted) Navigator.of(context).pop(code);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint('[OAuthWebView] Resource error (${error.errorCode}): ${error.description}');
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _loading = false;
                _errorMessage = 'Failed to load: ${error.description}';
              });
            }
          },
          onHttpError: (error) {
            debugPrint('[OAuthWebView] HTTP error ${error.response?.statusCode}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  /// Builds the WebView using Hybrid Composition on Android so that the Pico 4
  /// VR compositor can render the surface (SurfaceProducer is incompatible).
  Widget _buildWebView() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams
            .fromPlatformWebViewWidgetCreationParams(
          PlatformWebViewWidgetCreationParams(
            controller: _controller.platform,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          ),
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: _controller);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Google'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: Stack(
        children: [
          _buildWebView(),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _controller.loadRequest(
                        Uri.parse(widget.authUrl),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
