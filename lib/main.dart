import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'utils/localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  isGreekNotifier.value = prefs.getBool('isGreek') ?? false;
  runApp(const AppManagerApp());
}

class AppManagerApp extends StatelessWidget {
  const AppManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'VR App Manager',
          themeMode: currentMode,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF3F4F6),
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            colorScheme: const ColorScheme.light(
              primary: Colors.purple,
              secondary: Colors.pink,
            ),
            switchTheme: SwitchThemeData(
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(
              0xFF1E1E1E,
            ), // Darker background
            cardColor: const Color(0xFF2D2D30), // Slightly lighter for cards
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF252526), // VS Code like top bar
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            colorScheme: const ColorScheme.dark(
              primary: Colors.purpleAccent,
              secondary: Colors.pinkAccent,
              surface: Color(0xFF2D2D30),
            ),
            switchTheme: SwitchThemeData(
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.purpleAccent;
                }
                return const Color(0xFF3E3E42);
              }),
              thumbColor: WidgetStateProperty.all(Colors.white),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF3E3E42), // distinct from background
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintStyle: const TextStyle(color: Colors.white54),
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
