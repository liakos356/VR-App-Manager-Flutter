import 'package:flutter/material.dart';

import '../services/google_drive_service.dart';
import '../utils/build_info.dart';
import 'app_updater_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';

/// Root screen — handles Google auth gating.
///
/// Shows a loading spinner while silent sign-in is in progress, then routes
/// to [LoginScreen] (unauthenticated) or [MainScreen] (authenticated).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _initialized = false;
  StoreApkEntry? _newerApk;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await GoogleDriveService().signInSilently();
    if (mounted) {
      setState(() => _initialized = true);
      _checkForUpdate();
    }
  }

  /// Silently checks Drive for a newer APK after sign-in.
  Future<void> _checkForUpdate() async {
    final drive = GoogleDriveService();
    if (!drive.isSignedIn) return;
    try {
      final latest = await drive.latestStoreApk();
      if (latest == null) return;
      final current = _parseBuildTimestamp(kBuildTimestamp);
      if (current != null && latest.timestamp.isAfter(current)) {
        if (mounted) setState(() => _newerApk = latest);
      }
    } catch (_) {
      // Silent — never block startup on update-check failure.
    }
  }

  static DateTime? _parseBuildTimestamp(String ts) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})$').firstMatch(ts);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ValueListenableBuilder<GoogleUserInfo?>(
      valueListenable: GoogleDriveService().userNotifier,
      builder: (_, user, child) {
        if (user == null) return const LoginScreen();

        return Stack(
          children: [
            const MainScreen(),
            if (_newerApk != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _UpdateBanner(
                  entry: _newerApk!,
                  onDismiss: () => setState(() => _newerApk = null),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Update banner ──────────────────────────────────────────────────────────

class _UpdateBanner extends StatelessWidget {
  final StoreApkEntry entry;
  final VoidCallback onDismiss;

  const _UpdateBanner({required this.entry, required this.onDismiss});

  String _label(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$mo/$y $h:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.green.shade700,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.system_update_alt, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Update available: ${_label(entry.timestamp)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  onDismiss();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AppUpdaterScreen()),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Update'),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: onDismiss,
                tooltip: 'Dismiss',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
