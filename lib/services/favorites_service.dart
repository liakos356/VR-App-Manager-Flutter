import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorite_installed_apps';

  static Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.toSet();
  }

  static Future<void> saveFavorites(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, favorites.toList());
  }

  static Future<void> addFavorite(String packageName) async {
    final favorites = await loadFavorites();
    favorites.add(packageName);
    await saveFavorites(favorites);
  }

  static Future<void> removeFavorite(String packageName) async {
    final favorites = await loadFavorites();
    favorites.remove(packageName);
    await saveFavorites(favorites);
  }
}
