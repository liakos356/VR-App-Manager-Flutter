import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global singleton that tracks which store app IDs the signed-in user
/// has marked as favorites.
///
/// Backed by the `favorite_apps` Supabase table.  Identified by the
/// Google user e-mail (passed from [GoogleDriveService.userNotifier]).
class StoreFavoritesNotifier extends ValueNotifier<Set<String>> {
  StoreFavoritesNotifier._() : super(const {});

  static final StoreFavoritesNotifier instance = StoreFavoritesNotifier._();

  String? _userId;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once after the user signs in.  Loads their favorites from Supabase.
  Future<void> init(String userId) async {
    debugPrint('StoreFavorites: init called with userId="$userId"');
    _userId = userId;
    await _reload();
  }

  /// Clears in-memory state when the user signs out.
  void clear() {
    _userId = null;
    value = const {};
  }

  /// Adds or removes [appId] from the user's favorites and persists the change.
  Future<void> toggle(String appId) async {
    if (_userId == null || _userId!.isEmpty) return;
    if (value.contains(appId)) {
      await Supabase.instance.client
          .from('favorite_apps')
          .delete()
          .eq('user_id', _userId!)
          .eq('app_id', appId);
      value = Set.unmodifiable({...value}..remove(appId));
    } else {
      await Supabase.instance.client.from('favorite_apps').insert({
        'user_id': _userId!,
        'app_id': appId,
      });
      value = Set.unmodifiable({...value, appId});
    }
  }

  bool isFavorite(String appId) => value.contains(appId);

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _reload() async {
    if (_userId == null || _userId!.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('favorite_apps')
          .select('app_id')
          .eq('user_id', _userId!);
      value = Set.unmodifiable({
        for (final row in rows as List<dynamic>) row['app_id'].toString(),
      });
      debugPrint(
        'StoreFavorites: loaded ${value.length} favorites for $_userId',
      );
    } catch (e) {
      debugPrint('StoreFavorites: _reload failed — $e');
    }
  }
}
