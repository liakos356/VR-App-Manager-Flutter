import 'formatters.dart';

/// Pure data helpers for filtering and sorting the app list shown on
/// [MainScreen].  All functions are stateless and side-effect-free so they
/// are trivially testable.

// ── Category helpers ──────────────────────────────────────────────────────────

/// Returns the sorted set of categories present across [apps], always
/// starting with "All Categories".
List<String> availableCategories(List<dynamic> apps) {
  final categories = <String>{'All Categories'};
  for (final app in apps) {
    final catString = (app['categories'] ?? app['category'] ?? '').toString();
    for (final c in catString.split(',')) {
      final trimmed = c.trim();
      if (trimmed.isNotEmpty) categories.add(trimmed);
    }
  }
  return categories.toList()..sort((a, b) {
    if (a == 'All Categories') return -1;
    if (b == 'All Categories') return 1;
    return a.compareTo(b);
  });
}

/// Count of apps that belong to [category].
int categoryCount(List<dynamic> apps, String category) {
  if (category == 'All Categories') return apps.length;
  final catLower = category.toLowerCase();
  int count = 0;
  for (final app in apps) {
    final cats = (app['categories'] ?? app['category'] ?? '')
        .toString()
        .toLowerCase()
        .split(',');
    if (cats.any((c) => c.trim() == catLower)) count++;
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

// ── Filter + sort ─────────────────────────────────────────────────────────────

/// Applies search, category, ovrport, and type filters, then sorts the result.
List<dynamic> filteredAndSorted(
  List<dynamic> apps, {
  required String searchQuery,
  required String categoryFilter,
  required bool ovrportFilter,
  required String typeFilter,
  required String sortOption,
}) {
  final query = searchQuery.toLowerCase();

  final filtered = apps.where((app) {
    final name = (app['name'] ?? app['title'] ?? '').toString().toLowerCase();
    final category = (app['categories'] ?? app['category'] ?? '')
        .toString()
        .toLowerCase();
    final tags = (app['tags'] ?? '').toString().toLowerCase();

    final matchesSearch =
        name.contains(query) ||
        category.contains(query) ||
        tags.contains(query);

    final matchesCategory =
        categoryFilter == 'All Categories' ||
        category.contains(categoryFilter.toLowerCase());

    final matchesOvrport =
        !ovrportFilter ||
        app['ovrport'] == 1 ||
        app['ovrport'] == true ||
        app['ovrport'] == '1' ||
        app['ovrport'] == 'true';

    final appType = app['app_type']?.toString().toLowerCase() ?? 'app';
    final matchesType = typeFilter == 'all' || typeFilter == appType;

    return matchesSearch && matchesCategory && matchesOvrport && matchesType;
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
    default:
      return 0;
  }
}

String _name(dynamic app) =>
    (app['name'] ?? app['title'] ?? '').toString().toLowerCase();
