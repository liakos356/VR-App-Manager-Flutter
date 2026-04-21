import 'package:flutter/material.dart';

import '../services/google_drive_service.dart';

/// Full-screen login gate shown when no Google account is signed in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final success = await GoogleDriveService().startOAuthFlow(context);
      if (!success && mounted) {
        // User closed the WebView without completing sign-in.
        setState(() {
          _loading = false;
          _error = 'Sign-in cancelled. Please try again.';
        });
      }
      // On success the userNotifier updates → HomeScreen routes to MainScreen.
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Sign-in failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── App icon ─────────────────────────────────────────────
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.vrpano_rounded, size: 52, color: accent),
                  ),
                  const SizedBox(height: 28),

                  // ── Title ────────────────────────────────────────────────
                  Text(
                    'VR App Manager',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in with Google to access\nyour VR library on Drive.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ── Sign-in button ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _loading
                        ? Center(
                            child: CircularProgressIndicator(color: accent),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF2D2D30)
                                  : Colors.white,
                              foregroundColor: isDark
                                  ? Colors.white
                                  : Colors.black87,
                              elevation: 2,
                              side: BorderSide(
                                color: isDark ? Colors.white24 : Colors.black12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: _GoogleLogoIcon(),
                            label: const Text(
                              'Sign in with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: _signIn,
                          ),
                  ),

                  // ── Error message ────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Minimal Google "G" logo icon ─────────────────────────────────────────────

class _GoogleLogoIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = rect.center;
    final radius = size.width / 2;

    // Draw coloured arcs
    const segments = [
      (0.0, 0.5, Color(0xFF4285F4)), // blue
      (0.5, 0.75, Color(0xFF34A853)), // green
      (0.75, 0.875, Color(0xFFFBBC05)), // yellow
      (0.875, 1.0, Color(0xFFEA4335)), // red
    ];
    for (final (start, end, color) in segments) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.78),
        start * 2 * 3.141592653589793,
        (end - start) * 2 * 3.141592653589793,
        false,
        paint,
      );
    }

    // White cutout for the horizontal bar of the "G"
    final barPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - radius * 0.08,
        center.dy - radius * 0.18,
        radius * 0.9,
        radius * 0.36,
      ),
      barPaint,
    );

    // Blue fill for the bar
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - radius * 0.18,
        radius * 0.82,
        radius * 0.36,
      ),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
