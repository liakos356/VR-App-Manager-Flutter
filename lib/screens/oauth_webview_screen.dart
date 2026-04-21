import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Full-screen WebView that drives the Google OAuth 2.0 PKCE flow.
///
/// Intercepts navigation to the custom-scheme redirect URI and extracts the
/// authorisation code, returning it via [Navigator.pop].  Using a spoofed
/// Chrome user-agent prevents Google from flagging the session as an
/// embedded WebView and blocking the sign-in page.
class OAuthWebViewScreen extends StatefulWidget {
  final String authUrl;

  const OAuthWebViewScreen({super.key, required this.authUrl});

  @override
  State<OAuthWebViewScreen> createState() => _OAuthWebViewScreenState();
}

class _OAuthWebViewScreenState extends State<OAuthWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  // The custom scheme Google redirects to after authorisation.
  static const _callbackScheme =
      'com.googleusercontent.apps.1012473018198-r4fbunv4mq4mo0fegafkmqeoorllqr1v';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Spoof Chrome to avoid Google's embedded-WebView block.
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith(_callbackScheme)) {
              final uri = Uri.parse(request.url);
              final code = uri.queryParameters['code'];
              // Pop with the auth code (or null on error/cancel).
              if (mounted) Navigator.of(context).pop(code);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // Ignore errors for the callback scheme — expected on some
            // platforms where the OS tries to resolve the custom URI.
            debugPrint('[OAuthWebView] Resource error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
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
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
