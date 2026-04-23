import 'formatters.dart';

/// Pure data helpers for filtering and sorting the app list shown on
/// [MainScreen].  All functions are stateless and side-effect-free so they
/// are trivially testable.

// ── Genre helpers ─────────────────────────────────────────────────────────────

/// Extracts individual genre tokens from an app's genre/category string.
/// Handles both space-separated hashtag strings ("#Action #Adventure") and
/// comma-separated strings.
List<String> _parseGenres(String raw) {
  return raw
      .split(RegExp(r'[,\s]+'))
      .map((g) => g.trim())
      .where((g) => g.isNotEmpty)
      .toList();
}

String _genreRaw(dynamic app) =>
    (app['genres'] ?? app['categories'] ?? app['category'] ?? '').toString();

/// Returns the sorted set of individual genres present across [apps], always
/// starting with "All Genres".
List<String> availableGenres(List<dynamic> apps) {
  final genres = <String>{'All Genres'};
  for (final app in apps) {
    for (final g in _parseGenres(_genreRaw(app))) {
      genres.add(g);
    }
  }
  return genres.toList()..sort((a, b) {
    if (a == 'All Genres') return -1;
    if (b == 'All Genres') return 1;
    return a.compareTo(b);
  });
}

/// Count of apps that have [genre] as one of their individual genres.
int genreCount(List<dynamic> apps, String genre) {
  if (genre == 'All Genres') return apps.length;
  final genreLower = genre.toLowerCase();
  int count = 0;
  for (final app in apps) {
    final appGenres = _parseGenres(_genreRaw(app).toLowerCase());
    if (appGenres.any((g) => g == genreLower)) count++;
  }
  return count;
}

/// Returns the sorted set of distinct app-type strings present in [apps].
List<String> availableAppTypes(List<dynamic> apps) {
  final types =
      apps
          .map((app) {
            final type = app['app_type']?.toString().toLowerCase();
            return (type != null && type.isNotEmpty) ? type : 'app';
          })
          .toSet()
          .toList()
        ..sort();
  return types;
}

/// Computes a map of genre → count in a single O(n) pass.
///
/// Keys are lower-cased; `'all genres'` always maps to [apps.length].
/// This replaces repeated [genreCount] calls (one per genre per build) with a
/// single traversal that can be cached between builds.
Map<String, int> genreCountsMap(List<dynamic> apps) {
  final counts = <String, int>{'all genres': apps.length};
  for (final app in apps) {
    for (final g in _parseGenres(_genreRaw(app).toLowerCase())) {
      if (g.isNotEmpty) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
  }
  return counts;
}

/// Applies only the genre filter to an already-filtered and sorted list.
///
/// Because [apps] is already sorted by [filteredAndSorted], we can apply the
/// genre sub-filter without re-sorting — replacing a second O(n log n) pass
/// with an O(n) one.
List<dynamic> applyGenreFilter(List<dynamic> apps, String genreFilter) {
  if (genreFilter == 'All Genres') return apps;
  final genreLower = genreFilter.toLowerCase();
  return apps.where((app) {
    final appGenres = _parseGenres(_genreRaw(app).toLowerCase());
    return appGenres.any((g) => g == genreLower);
  }).toList();
}

// ── Fuzzy search ──────────────────────────────────────────────────────────────

/// Returns true if every character in [query] appears in [text] in the same
/// order (subsequence match).  Both arguments are expected to be lower-cased
/// by the caller.  An empty query always matches.
bool _fuzzyMatch(String text, String query) {
  if (query.isEmpty) return true;
  int qi = 0;
  for (int i = 0; i < text.length && qi < query.length; i++) {
    if (text[i] == query[qi]) qi++;
  }
  return qi == query.length;
}

// ── Filter + sort ─────────────────────────────────────────────────────────────

/// Applies search, genre, ovrport, type, and availability filters, then sorts.
List<dynamic> filteredAndSorted(
  List<dynamic> apps, {
  required String searchQuery,
  required String genreFilter,
  required bool ovrportFilter,
  required String typeFilter,
  required String sortOption,
  bool availableOnly = false,
  bool updatedRecentlyFilter = false,
}) {
  final query = searchQuery.toLowerCase();

  final filtered = apps.where((app) {
    final name = (app['name'] ?? app['title'] ?? '').toString().toLowerCase();
    final genreRaw = _genreRaw(app).toLowerCase();
    final tags = (app['tags'] ?? '').toString().toLowerCase();

    final matchesSearch =
        _fuzzyMatch(name, query) ||
        genreRaw.contains(query) ||
        tags.contains(query);

    final matchesGenre =
        genreFilter == 'All Genres' ||
        _parseGenres(genreRaw).any(
          (g) => g == genreFilter.toLowerCase(),
        );

    final matchesOvrport =
        !ovrportFilter ||
        app['ovrport'] == 1 ||
        app['ovrport'] == true ||
        app['ovrport'] == '1' ||
        app['ovrport'] == 'true';

    final appType = app['app_type']?.toString().toLowerCase() ?? 'app';
    final matchesType = typeFilter == 'all' || typeFilter == appType;

    final apkPath = app['apk_path']?.toString().trim();
    final matchesAvailability =
        !availableOnly || (apkPath != null && apkPath.isNotEmpty);

    bool matchesUpdatedRecently = true;
    if (updatedRecentlyFilter) {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      final updatedAt =
          DateTime.tryParse(app['updated_at']?.toString() ?? '');
      matchesUpdatedRecently =
          updatedAt != null && updatedAt.isAfter(oneWeekAgo);
    }

    return matchesSearch && matchesGenre && matchesOvrport && matchesType && matchesAvailability && matchesUpdatedRecently;
  }).toList();

  filtered.sort((a, b) => _compare(a, b, sortOption));
  return filtered;
}

int _compare(dynamic a, dynamic b, String sortOption) {
  switch (sortOption) {
    case 'Name (A-Z)':
      return _name(a).compareTo(_name(b));
    case 'Name (Z-A)':
      return _name(b).compareTo(_name(a));
    case 'Rating (High to Low)':
      return parseRating(
        b['user_rating'] ?? b['rating'],
      ).compareTo(parseRating(a['user_rating'] ?? a['rating']));
    case 'Rating (Low to High)':
      return parseRating(
        a['user_rating'] ?? a['rating'],
      ).compareTo(parseRating(b['user_rating'] ?? b['rating']));
    case 'Size (Large to Small)':
      return getAppSize(b).compareTo(getAppSize(a));
    case 'Size (Small to Large)':
      return getAppSize(a).compareTo(getAppSize(b));
    case 'Newest First':
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    case 'Oldest First':
      final aDateO = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDateO = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (aDateO == null && bDateO == null) return 0;
      if (aDateO == null) return 1;
      if (bDateO == null) return -1;
      return aDateO.compareTo(bDateO);
    default:
      return 0;
  }
}

String _name(dynamic app) =>
    (app['name'] ?? app['title'] ?? '').toString().toLowerCase();
