import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'utils/installed_apps_cache.dart';
import 'utils/localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gbunixrrvpikpqsrnfkp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdidW5peHJydnBpa3Bxc3JuZmtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3MzkwMDIsImV4cCI6MjA5MjMxNTAwMn0.0yjaD1ih9laJCS4j8Jg8QDgMTawi0N7agsOP68yEF3Q',
  );

  // Limit image cache size to prevent OOM errors on heavy lists
  PaintingBinding.instance.imageCache.maximumSize = 100; // max 100 images
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB max

  // Load SharedPreferences asynchronously — do not block runApp().
  // isGreekNotifier defaults to false (English), so a slightly-deferred
  // language update causes no visible flash.  Theme defaults to system.
  SharedPreferences.getInstance().then((prefs) {
    isGreekNotifier.value = prefs.getBool('isGreek') ?? false;
    accentIndexNotifier.value = (prefs.getInt('accentColorIndex') ?? 0).clamp(
      0,
      accentColorOptions.length - 1,
    );
    final themePref = prefs.getString('themeMode');
    if (themePref == 'dark') {
      themeNotifier.value = ThemeMode.dark;
    } else if (themePref == 'light') {
      themeNotifier.value = ThemeMode.light;
    }
    uiScaleNotifier.value = (prefs.getDouble('uiScale') ?? 1.0).clamp(0.7, 1.5);
  });

  // Pre-warm the installed-apps cache now so that when the grid renders
  // and cards check install state, the IPC is already complete.
  InstalledAppsCache.get().ignore();

  runApp(const AppManagerApp());
}

class AppManagerApp extends StatelessWidget {
  const AppManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return ValueListenableBuilder<int>(
          valueListenable: accentIndexNotifier,
          builder: (_, int accentIdx, _) {
            final lightAccent = accentColorOptions[accentIdx].lightColor;
            final darkAccent = accentColorOptions[accentIdx].darkColor;
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
                colorScheme: ColorScheme.light(
                  primary: lightAccent,
                  secondary: lightAccent,
                ),
                switchTheme: SwitchThemeData(
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
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
                scaffoldBackgroundColor: const Color(0xFF1E1E1E),
                cardColor: const Color(0xFF2D2D30),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF252526),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                colorScheme: ColorScheme.dark(
                  primary: darkAccent,
                  secondary: darkAccent,
                  surface: const Color(0xFF2D2D30),
                ),
                switchTheme: SwitchThemeData(
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                  trackColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return darkAccent;
                    }
                    return const Color(0xFF3E3E42);
                  }),
                  thumbColor: WidgetStateProperty.all(Colors.white),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFF3E3E42),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: const TextStyle(color: Colors.white54),
                ),
              ),
              builder: (context, child) {
                return ValueListenableBuilder<double>(
                  valueListenable: uiScaleNotifier,
                  builder: (_, scale, _) {
                    if (scale == 1.0) return child!;
                    final mq = MediaQuery.of(context);
                    final virtualWidth = mq.size.width / scale;
                    final virtualHeight = mq.size.height / scale;
                    // FittedBox correctly scales both rendering AND hit-testing.
                    // The inner SizedBox lays out at virtualSize (same aspect
                    // ratio as realSize), so FittedBox.fill = FittedBox.contain
                    // and no distortion or empty space occurs.
                    return SizedBox(
                      width: mq.size.width,
                      height: mq.size.height,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: virtualWidth,
                          height: virtualHeight,
                          child: MediaQuery(
                            data: mq.copyWith(
                              size: Size(virtualWidth, virtualHeight),
                            ),
                            child: child!,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              home: const HomeScreen(),
            );
          },
        );
      },
    );
  }
}
