import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db_service.dart';
import '../utils/app_filter.dart' as filter;
import '../utils/localization.dart';
import '../widgets/adjustable_split_view.dart';
import '../widgets/app_card.dart';
import '../widgets/app_detail_panel.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/app_search_field.dart';
import '../widgets/main_filter_bar.dart';

const String _kApiUrl = 'http://192.168.1.17:8001/api';

// ── Widget ────────────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  // ── Data ──────────────────────────────────────────────────────────────────

  List<dynamic> _apps = [];
  List<dynamic> _cachedFilteredApps = [];
  String? _fetchError;
  bool _isLoading = false;
  double _downloadProgress = -1.0;

  // ── Filter / sort state ───────────────────────────────────────────────────

  String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';
  String _categoryFilter = 'All Categories';
  bool _ovrportFilter = false;
  String _typeFilter = 'all';

  // ── View state ────────────────────────────────────────────────────────────

  String _viewMode = 'grid'; // 'grid' | 'master_detail'
  int _selectedMasterDetailIndex = 0;

  // ── Search ────────────────────────────────────────────────────────────────

  List<String> _searchHistory = [];
  final SearchController _searchController = SearchController();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _fetchApps();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _refilter();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Search history ────────────────────────────────────────────────────────

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _searchHistory = prefs.getStringList('searchHistory') ?? []);
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    var history = prefs.getStringList('searchHistory') ?? [];
    history
      ..remove(query)
      ..insert(0, query);
    if (history.length > 4) history = history.sublist(0, 4);
    await prefs.setStringList('searchHistory', history);
    setState(() => _searchHistory = history);
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('searchHistory');
    setState(() => _searchHistory = []);
  }

  // ── App fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchApps({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _fetchError = null;
      _downloadProgress = -1.0;
    });
    try {
      final smbApps = await fetchAppsFromDb(
        'smb://100.95.32.89/ssd_internal/downloads/pico4/apps/apps.db',
        forceRefresh: forceRefresh,
        onProgress: (p) => setState(() => _downloadProgress = p),
      );
      setState(() {
        _apps = smbApps;
        _refilter();
      });
    } catch (e) {
      debugPrint('Error fetching apps from DB: $e');
      setState(() => _fetchError = e.toString());
    } finally {
      setState(() {
        _isLoading = false;
        _downloadProgress = -1.0;
      });
    }
  }

  // ── Derived data (delegates to app_filter.dart) ───────────────────────────

  List<String> get _availableCategories => filter.availableCategories(_apps);

  int _getCategoryCount(String category) =>
      filter.categoryCount(_apps, category);

  List<String> get _availableAppTypes => filter.availableAppTypes(_apps);

  /// Recomputes the filtered+sorted list into [_cachedFilteredApps].
  /// Call this inside every [setState] that changes a filter input or [_apps].
  void _refilter() {
    _cachedFilteredApps = filter.filteredAndSorted(
      _apps,
      searchQuery: _searchQuery,
      categoryFilter: _categoryFilter,
      ovrportFilter: _ovrportFilter,
      typeFilter: _typeFilter,
      sortOption: _sortOption,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final displayedApps = _cachedFilteredApps;

    return ValueListenableBuilder<bool>(
      valueListenable: isGreekNotifier,
      builder: (context, isGreek, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text(
                  "Liako's App Store",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                const SizedBox(width: 16),
                AppTypeSegmentedButton(
                  availableTypes: _availableAppTypes,
                  selected: _typeFilter,
                  onChanged: (t) => setState(() {
                    _typeFilter = t;
                    _refilter();
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: AppSearchField(
                      apps: _apps,
                      searchHistory: _searchHistory,
                      controller: _searchController,
                      onSaveHistory: _saveSearchHistory,
                      onClearHistory: _clearSearchHistory,
                    ),
                  ),
                ),
              ],
            ),
            bottom: MainFilterBar(
              categoryFilter: _categoryFilter,
              availableCategories: _availableCategories,
              getCategoryCount: _getCategoryCount,
              ovrportFilter: _ovrportFilter,
              viewMode: _viewMode,
              sortOption: _sortOption,
              onCategoryChanged: (v) {
                if (v != null)
                  setState(() {
                    _categoryFilter = v;
                    _refilter();
                  });
              },
              onOvrportChanged: (v) => setState(() {
                _ovrportFilter = v;
                _refilter();
              }),
              onViewModeChanged: (v) => setState(() => _viewMode = v),
              onSortChanged: (v) {
                if (v != null)
                  setState(() {
                    _sortOption = v;
                    _refilter();
                  });
              },
            ),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    '(${displayedApps.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: isGreekNotifier,
                builder: (context, isGreek, _) {
                  return IconButton(
                    icon: Text(
                      isGreek ? 'GR' : 'EN',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onPressed: () async {
                      isGreekNotifier.value = !isGreekNotifier.value;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isGreek', isGreekNotifier.value);
                    },
                    tooltip: tr('Toggle Language'),
                  );
                },
              ),
              IconButton(
                icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => themeNotifier.value = isDarkMode
                    ? ThemeMode.light
                    : ThemeMode.dark,
                tooltip: tr('Toggle Theme'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _fetchApps(forceRefresh: true),
                tooltip: tr('Refresh Apps'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: _isLoading
              ? _LoadingBody(downloadProgress: _downloadProgress)
              : _fetchError != null
              ? _ErrorBody(
                  message: _fetchError!,
                  onRetry: () => _fetchApps(forceRefresh: true),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (_viewMode == 'master_detail') {
                      return _buildMasterDetailView(displayedApps);
                    }
                    return _AppGrid(
                      apps: displayedApps,
                      apiUrl: _kApiUrl,
                      constraints: constraints,
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildMasterDetailView(List<dynamic> displayedApps) {
    if (displayedApps.isEmpty) {
      return Center(child: Text(tr('No apps found')));
    }
    if (_selectedMasterDetailIndex >= displayedApps.length) {
      _selectedMasterDetailIndex = 0;
    }
    final selectedApp = displayedApps[_selectedMasterDetailIndex];

    return AdjustableSplitView(
      left: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: displayedApps.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return AppListTile(
            app: displayedApps[index],
            isSelected: index == _selectedMasterDetailIndex,
            apiUrl: _kApiUrl,
            onTap: () => setState(() => _selectedMasterDetailIndex = index),
          );
        },
      ),
      right: AppDetailPanel(app: selectedApp, apiUrl: _kApiUrl),
    );
  }
}

// ── Local private widgets ─────────────────────────────────────────────────────
// These widgets are only used by this file, so they remain private.

class _LoadingBody extends StatelessWidget {
  final double downloadProgress;
  const _LoadingBody({required this.downloadProgress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (downloadProgress < 0)
            const CircularProgressIndicator()
          else
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(value: downloadProgress),
            ),
          const SizedBox(height: 16),
          Text(
            downloadProgress < 0
                ? 'Fetching database...'
                : 'Fetching database... ${(downloadProgress * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _AppGrid extends StatelessWidget {
  final List<dynamic> apps;
  final String apiUrl;
  final BoxConstraints constraints;

  const _AppGrid({
    required this.apps,
    required this.apiUrl,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final int crossAxisCount = constraints.maxWidth > 1200
        ? 5
        : constraints.maxWidth > 800
        ? 4
        : 2;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: apps.length,
      itemBuilder: (_, index) => AppCard(
        key: ValueKey(apps[index]['id'] ?? index),
        app: apps[index],
        apiUrl: apiUrl,
      ),
    );
  }
}

/// Full-screen error widget shown when [MainScreenState._fetchApps] throws.
class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
            const SizedBox(height: 24),
            Text(
              'Failed to load apps',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
