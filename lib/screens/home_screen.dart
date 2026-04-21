import 'package:flutter/material.dart';

import '../services/google_drive_service.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await GoogleDriveService().signInSilently();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ValueListenableBuilder<GoogleUserInfo?>(
      valueListenable: GoogleDriveService().userNotifier,
      builder: (_, user, child) {
        return user != null ? const MainScreen() : const LoginScreen();
      },
    );
  }
}
