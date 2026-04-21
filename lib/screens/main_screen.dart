import 'dart:async';

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
import '../widgets/genre_side_panel.dart';
import '../widgets/main_filter_bar.dart';
import 'installed_apps_screen.dart';

const String _kApiUrl = 'http://192.168.1.17:8001/api';

// ── Widget ────────────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Data ──────────────────────────────────────────────────────────────────

  List<dynamic> _apps = [];
  List<dynamic> _cachedFilteredApps = [];
  List<dynamic> _cachedPreGenreFilteredApps = [];
  // Cached genre metadata – recomputed in _refilter(), read during builds.
  List<String> _cachedAvailableGenresList = const ['All Genres'];
  Map<String, int> _cachedGenreCounts = const {'all genres': 0};
  String? _fetchError;
  bool _isLoading = false;
  double _downloadProgress = -1.0;

  // ── Pagination ────────────────────────────────────────────────────────────
  int _totalCount = 0;
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool get _hasMore => _apps.length < _totalCount;

  // ── Filter / sort state ───────────────────────────────────────────────────

  String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';
  String _genreFilter = 'All Genres';
  bool _ovrportFilter = false;
  bool _availableOnly = false;
  bool _updatedRecentlyFilter = false;
  String _typeFilter = 'all';

  // ── View state ────────────────────────────────────────────────────────────

  String _viewMode = 'grid'; // 'grid' | 'master_detail'
  bool _genreSidebarOpen = true;
  int _selectedMasterDetailIndex = 0;
  late final ValueNotifier<double> _cardSizeNotifier;

  // ── Screen Mode ───────────────────────────────────────────────────────────
  bool _showInstalledApps = false;
  int _installedAppsCount = 0;

  // ── Search ────────────────────────────────────────────────────────────────

  List<String> _searchHistory = [];
  final SearchController _searchController = SearchController();
  Timer? _savePrefsDebounce;
  Timer? _searchDebounce;

  // Cached SharedPreferences instance — obtained once in initState so every
  // subsequent read/write bypasses the async Dart-plugin bridge overhead.
  SharedPreferences? _prefs;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _cardSizeNotifier = ValueNotifier<double>(1.0);
    // Obtain SharedPreferences once; load prefs + history when ready.
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      _loadPreferences(prefs);
      _loadSearchHistory(prefs);
    });
    _fetchApps();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _searchQuery = _searchController.text;
            _refilter();
          });
        }
      });
    });
    _cardSizeNotifier.addListener(_savePreferences);
  }

  @override
  void dispose() {
    _savePrefsDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _cardSizeNotifier.dispose();
    super.dispose();
  }

  // ── Preferences persistence ───────────────────────────────────────────────

  void _loadPreferences(SharedPreferences prefs) {
    if (!mounted) return;
    setState(() {
      _sortOption = prefs.getString('sortOption') ?? 'Name (A-Z)';
      _genreFilter = prefs.getString('genreFilter') ?? 'All Genres';
      _ovrportFilter = prefs.getBool('ovrportFilter') ?? false;
      _availableOnly = prefs.getBool('availableOnly') ?? false;
      _updatedRecentlyFilter = prefs.getBool('updatedRecentlyFilter') ?? false;
      _typeFilter = prefs.getString('typeFilter') ?? 'all';
      _viewMode = prefs.getString('viewMode') ?? 'grid';
      _genreSidebarOpen = prefs.getBool('genreSidebarOpen') ?? true;
      _cardSizeNotifier.value = prefs.getDouble('cardSize') ?? 1.0;
      _refilter();
    });
  }

  Future<void> _savePreferences() async {
    _savePrefsDebounce?.cancel();
    _savePrefsDebounce = Timer(const Duration(milliseconds: 500), () async {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString('sortOption', _sortOption);
      await prefs.setString('genreFilter', _genreFilter);
      await prefs.setBool('ovrportFilter', _ovrportFilter);
      await prefs.setBool('availableOnly', _availableOnly);
      await prefs.setBool('updatedRecentlyFilter', _updatedRecentlyFilter);
      await prefs.setString('typeFilter', _typeFilter);
      await prefs.setString('viewMode', _viewMode);
      await prefs.setBool('genreSidebarOpen', _genreSidebarOpen);
      await prefs.setDouble('cardSize', _cardSizeNotifier.value);
    });
  }

  // ── Search history ────────────────────────────────────────────────────────

  void _loadSearchHistory(SharedPreferences prefs) {
    if (!mounted) return;
    setState(() => _searchHistory = prefs.getStringList('searchHistory') ?? []);
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    var history = prefs.getStringList('searchHistory') ?? [];
    history
      ..remove(query)
      ..insert(0, query);
    if (history.length > 4) history = history.sublist(0, 4);
    await prefs.setStringList('searchHistory', history);
    if (mounted) setState(() => _searchHistory = history);
  }

  Future<void> _clearSearchHistory() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove('searchHistory');
    if (mounted) setState(() => _searchHistory = []);
  }

  // ── App fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchApps({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _fetchError = null;
      _downloadProgress = -1.0;
      _currentPage = 0;
      _totalCount = 0;
    });
    try {
      final result = await fetchAppsFromDb(
        'smb://100.95.32.89/ssd_internal/downloads/pico4/apps/apps.db',
        forceRefresh: forceRefresh,
        onProgress: (p) => setState(() => _downloadProgress = p),
        page: 0,
      );
      setState(() {
        _apps = result.apps;
        _totalCount = result.totalCount;
        _currentPage = 1;
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

  Future<void> _loadMoreApps() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await fetchAppsFromDb(
        'smb://100.95.32.89/ssd_internal/downloads/pico4/apps/apps.db',
        page: _currentPage,
      );
      setState(() {
        _apps = [..._apps, ...result.apps];
        _totalCount = result.totalCount;
        _currentPage++;
        _refilter();
      });
    } catch (e) {
      debugPrint('Error loading more apps: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── Derived data (delegates to app_filter.dart) ───────────────────────────

  /// Genre list for the side panel – read from cache, updated in [_refilter].
  List<String> get _availableGenres => _cachedAvailableGenresList;

  /// Per-genre count – read from the pre-computed map, no per-build traversal.
  int _getGenreCount(String genre) =>
      _cachedGenreCounts[genre.toLowerCase()] ?? 0;

  /// Recomputes the filtered+sorted list into [_cachedFilteredApps].
  /// Also recomputes [_cachedPreGenreFilteredApps] which is used by the genre
  /// side panel to show only genres/counts relevant to the active filters.
  /// Call this inside every [setState] that changes a filter input or [_apps].
  void _refilter() {
    // Single O(n log n) sort pass for the base (non-genre) filtered list.
    _cachedPreGenreFilteredApps = filter.filteredAndSorted(
      _apps,
      searchQuery: _searchQuery,
      genreFilter: 'All Genres',
      ovrportFilter: _ovrportFilter,
      availableOnly: _availableOnly,
      updatedRecentlyFilter: _updatedRecentlyFilter,
      typeFilter: _typeFilter,
      sortOption: _sortOption,
    );

    // Compute genre metadata once here so build() just reads cached values.
    _cachedAvailableGenresList = filter.availableGenres(
      _cachedPreGenreFilteredApps,
    );
    _cachedGenreCounts = filter.genreCountsMap(_cachedPreGenreFilteredApps);

    // If the selected genre is no longer present, reset to avoid empty list.
    if (_genreFilter != 'All Genres' &&
        !_cachedAvailableGenresList.contains(_genreFilter)) {
      _genreFilter = 'All Genres';
    }

    // Apply genre sub-filter on the already-sorted list — O(n) instead of
    // a second O(n log n) pass through filteredAndSorted.
    _cachedFilteredApps = filter.applyGenreFilter(
      _cachedPreGenreFilteredApps,
      _genreFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedApps = _cachedFilteredApps;

    return ValueListenableBuilder<bool>(
      valueListenable: isGreekNotifier,
      builder: (context, isGreek, _) {
        return Scaffold(
          key: _scaffoldKey,
          endDrawer: _buildSettingsDrawer(context),
          appBar: AppBar(
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "App Manager",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
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
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    _showInstalledApps
                        ? '($_installedAppsCount)'
                        : _totalCount > 0
                        ? '(${displayedApps.length} / $_totalCount)'
                        : '(${displayedApps.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                tooltip: 'Settings',
              ),
              const SizedBox(width: 8),
            ],
          ),
          // body contents
          body: _showInstalledApps
              ? InstalledAppsScreen(
                  searchQuery: _searchQuery,
                  onToggleInstalledApps: (v) =>
                      setState(() => _showInstalledApps = v),
                  onAppCountChanged: (count) {
                    if (_installedAppsCount != count) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _installedAppsCount = count);
                        }
                      });
                    }
                  },
                )
              : Column(
                  children: [
                    MainFilterBar(
                      viewMode: _viewMode,
                      sortOption: _sortOption,
                      genreSidebarOpen: _genreSidebarOpen,
                      genreFilter: _genreFilter,
                      onGenreToggle: () => setState(() {
                        _genreSidebarOpen = !_genreSidebarOpen;
                        _savePreferences();
                      }),
                      onClearGenre: () => setState(() {
                        _genreFilter = 'All Genres';
                        _refilter();
                        _savePreferences();
                      }),
                      onViewModeChanged: (v) => setState(() {
                        _viewMode = v;
                        _savePreferences();
                      }),
                      onSortChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _sortOption = v;
                            _refilter();
                            _savePreferences();
                          });
                        }
                      },
                      showInstalledApps: _showInstalledApps,
                      onToggleInstalledApps: (v) => setState(() {
                        _showInstalledApps = v;
                      }),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          GenreSidePanel(
                            genres: _availableGenres,
                            selected: _genreFilter,
                            getGenreCount: _getGenreCount,
                            onChanged: (v) => setState(() {
                              _genreFilter = v;
                              _refilter();
                              _savePreferences();
                            }),
                            isOpen: _genreSidebarOpen,
                            onToggle: () => setState(() {
                              _genreSidebarOpen = !_genreSidebarOpen;
                              _savePreferences();
                            }),
                          ),
                          Expanded(
                            child: _isLoading
                                ? _LoadingBody(
                                    downloadProgress: _downloadProgress,
                                  )
                                : _fetchError != null
                                ? _ErrorBody(
                                    message: _fetchError!,
                                    onRetry: () =>
                                        _fetchApps(forceRefresh: true),
                                  )
                                : ValueListenableBuilder<double>(
                                    valueListenable: _cardSizeNotifier,
                                    builder: (context, cardSize, _) {
                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          if (_viewMode == 'master_detail') {
                                            return _buildMasterDetailView(
                                              displayedApps,
                                            );
                                          }
                                          return _AppGrid(
                                            apps: displayedApps,
                                            apiUrl: _kApiUrl,
                                            constraints: constraints,
                                            cardSizeMultiplier: cardSize,
                                            onLoadMore: _hasMore
                                                ? _loadMoreApps
                                                : null,
                                            isLoadingMore: _isLoadingMore,
                                            hasMore: _hasMore,
                                          );
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Drawer _buildSettingsDrawer(BuildContext context) {
    return Drawer(
      width: 340,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'Settings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            // ── Language ──────────────────────────────────────────────────
            ValueListenableBuilder<bool>(
              valueListenable: isGreekNotifier,
              builder: (context, isGreek, _) {
                return ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isGreek ? 'GR' : 'EN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  onTap: () async {
                    isGreekNotifier.value = !isGreekNotifier.value;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isGreek', isGreekNotifier.value);
                  },
                );
              },
            ),
            // ── Theme ─────────────────────────────────────────────────────
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, mode, _) {
                final dark = mode == ThemeMode.dark;
                return ListTile(
                  leading: Icon(dark ? Icons.light_mode : Icons.dark_mode),
                  title: const Text('Theme'),
                  trailing: Text(
                    dark ? 'Dark' : 'Light',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => themeNotifier.value = dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                );
              },
            ),
            // ── Ovrport Only ───────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.vrpano_outlined),
              title: const Text('Ovrport Only'),
              subtitle: const Text('Show only Ovrport-compatible apps'),
              trailing: Switch(
                value: _ovrportFilter,
                onChanged: (v) => setState(() {
                  _ovrportFilter = v;
                  _refilter();
                  _savePreferences();
                }),
              ),
            ),
            // ── Available Only ─────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Available Only'),
              subtitle: const Text('Hide apps not on the server'),
              trailing: Switch(
                value: _availableOnly,
                onChanged: (v) => setState(() {
                  _availableOnly = v;
                  _refilter();
                  _savePreferences();
                }),
              ),
            ),
            // ── Updated Recently ───────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.new_releases_outlined),
              title: const Text('Updated Recently'),
              subtitle: const Text('Show only apps updated in the last 7 days'),
              trailing: Switch(
                value: _updatedRecentlyFilter,
                onChanged: (v) => setState(() {
                  _updatedRecentlyFilter = v;
                  _refilter();
                  _savePreferences();
                }),
              ),
            ),
            // ── Reload Database ────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Reload Database'),
              onTap: () {
                _scaffoldKey.currentState?.closeEndDrawer();
                _fetchApps(forceRefresh: true);
              },
            ),
            const Divider(),
            // ── Card Size slider ───────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.grid_view_rounded),
                  SizedBox(width: 12),
                  Text('Card Size', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: _cardSizeNotifier,
              builder: (context, cardSize, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.crop_square,
                            size: 16,
                            color: Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                          ),
                          Expanded(
                            child: Slider(
                              value: cardSize,
                              min: 0.5,
                              max: 2.0,
                              divisions: 6,
                              label: '${cardSize.toStringAsFixed(1)}×',
                              onChanged: (v) => _cardSizeNotifier.value = v,
                            ),
                          ),
                          Icon(
                            Icons.crop_square,
                            size: 28,
                            color: Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                      Text(
                        '${cardSize.toStringAsFixed(1)}× size',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            // ── Installed Apps ─────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.install_mobile),
              title: const Text('Installed Apps'),
              onTap: () {
                _scaffoldKey.currentState?.closeEndDrawer();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InstalledAppsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
        addAutomaticKeepAlives: false,
        padding: const EdgeInsets.all(16),
        itemCount: displayedApps.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == displayedApps.length) {
            if (!_isLoadingMore) _loadMoreApps();
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
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

class _AppGrid extends StatefulWidget {
  final List<dynamic> apps;
  final String apiUrl;
  final BoxConstraints constraints;
  final double cardSizeMultiplier;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final bool hasMore;

  const _AppGrid({
    required this.apps,
    required this.apiUrl,
    required this.constraints,
    this.cardSizeMultiplier = 1.0,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.hasMore = false,
  });

  @override
  State<_AppGrid> createState() => _AppGridState();
}

class _AppGridState extends State<_AppGrid> {
  final ScrollController _scrollController = ScrollController();
  bool _showFab = false;
  bool _requestedMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 300;
      if (show != _showFab) setState(() => _showFab = show);

      // Trigger load-more when within 500px of the bottom.
      if (!_requestedMore &&
          widget.hasMore &&
          !widget.isLoadingMore &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 500) {
        _requestedMore = true;
        widget.onLoadMore?.call();
      }
    });
  }

  @override
  void didUpdateWidget(_AppGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset the guard once the previous load finishes so the next scroll
    // to bottom triggers another fetch.
    if (oldWidget.isLoadingMore && !widget.isLoadingMore) {
      _requestedMore = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int baseCount = widget.constraints.maxWidth > 1200
        ? 5
        : widget.constraints.maxWidth > 800
        ? 4
        : 2;
    final int crossAxisCount = (baseCount / widget.cardSizeMultiplier)
        .round()
        .clamp(1, 10);

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                delegate: SliverChildBuilderDelegate(
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  (_, index) => AppCard(
                    key: ValueKey(widget.apps[index]['id'] ?? index),
                    app: widget.apps[index],
                    apiUrl: widget.apiUrl,
                  ),
                  childCount: widget.apps.length,
                ),
              ),
            ),
            if (widget.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: AnimatedOpacity(
            opacity: _showFab ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showFab,
              child: FloatingActionButton.small(
                onPressed: () => _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                ),
                tooltip: 'Scroll to top',
                child: const Icon(Icons.keyboard_arrow_up),
              ),
            ),
          ),
        ),
      ],
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
