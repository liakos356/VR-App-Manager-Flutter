import 'package:flutter/material.dart';

import 'main_screen.dart';

/// Root screen — wraps [MainScreen].
/// Installed Apps is accessible via the settings menu inside [MainScreen].
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const MainScreen();
}
