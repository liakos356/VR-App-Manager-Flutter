import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db_service.dart';
import '../services/download_jobs_notifier.dart';
import '../services/google_drive_service.dart';
import '../services/store_favorites_service.dart';
import '../utils/app_filter.dart' as filter;
import '../utils/localization.dart';
import '../widgets/adjustable_split_view.dart';
import '../widgets/alpha_index_column.dart';
import '../widgets/app_card.dart';
import '../widgets/app_detail_panel.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/app_search_field.dart';
import '../widgets/genre_side_panel.dart';
import '../widgets/install_bottom_sheet.dart';
import '../widgets/main_filter_bar.dart';
import '../widgets/settings_side_panel.dart';
import 'app_updater_screen.dart';
import 'download_queue_screen.dart';
import 'installed_apps_screen.dart';

const String _kApiUrl = 'http://192.168.1.17:8001/api';

// ── Widget ────────────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  // Settings side-panel open/close state
  bool _settingsPanelOpen = false;

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

  // ── Filter / sort state ───────────────────────────────────────────────────

  String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';
  String _genreFilter = 'All Genres';
  bool _ovrportFilter = false;
  bool _availableOnly = false;
  bool _updatedRecentlyFilter = false;
  int _updatedRecentlyDays = 7;
  String _typeFilter = 'all';
  bool _favoritesOnly = false;

  // ── View state ────────────────────────────────────────────────────────────

  String _viewMode = 'grid'; // 'grid' | 'master_detail'
  bool _genreSidebarOpen = true;
  int _selectedMasterDetailIndex = 0;
  late final ValueNotifier<double> _cardSizeNotifier;

  // ── Alphabet index ────────────────────────────────────────────────────────

  final GlobalKey<_AppGridState> _appGridKey = GlobalKey<_AppGridState>();
  late final ScrollController _masterDetailScrollController;

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
    _masterDetailScrollController = ScrollController();
    // Obtain SharedPreferences once; load prefs + history when ready.
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      _loadPreferences(prefs);
      _loadSearchHistory(prefs);
    });
    _fetchApps();
    // Init store favorites for the currently signed-in Google user.
    final userEmail = GoogleDriveService().userNotifier.value?.email;
    if (userEmail != null && userEmail.isNotEmpty) {
      StoreFavoritesNotifier.instance.init(userEmail);
    }
    // Refilter whenever favorites change (e.g. user toggles a favorite while
    // the favorites-only filter is active).
    StoreFavoritesNotifier.instance.addListener(_onFavoritesChanged);
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

    // Start download-jobs polling and register the "App Ready" callback.
    DownloadJobsNotifier.instance.onJobDone = _onDownloadJobDone;
    DownloadJobsNotifier.instance.startPolling();
  }

  @override
  void dispose() {
    _savePrefsDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _cardSizeNotifier.dispose();
    _masterDetailScrollController.dispose();
    StoreFavoritesNotifier.instance.removeListener(_onFavoritesChanged);
    DownloadJobsNotifier.instance.stopPolling();
    DownloadJobsNotifier.instance.onJobDone = null;
    super.dispose();
  }

  // ── Preferences persistence ───────────────────────────────────────────────

  void _onFavoritesChanged() {
    if (mounted && _favoritesOnly) setState(() => _refilter());
  }

  void _onDownloadJobDone(Map<String, dynamic> job) {
    if (!mounted) return;
    final app = job['apps'] as Map<String, dynamic>?;
    final appName = app?['name'] ?? app?['title'] ?? 'App';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tr('Ready to install')}: $appName'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: tr('Install Now'),
          onPressed: () {
            if (app != null) {
              showInstallBottomSheet(
                context,
                app: app,
                isInstalled: false,
                installedPackageName: '',
                onInstallDone: () {},
              );
            }
          },
        ),
      ),
    );
  }

  void _loadPreferences(SharedPreferences prefs) {
    if (!mounted) return;
    setState(() {
      _sortOption = prefs.getString('sortOption') ?? 'Name (A-Z)';
      _genreFilter = prefs.getString('genreFilter') ?? 'All Genres';
      _ovrportFilter = prefs.getBool('ovrportFilter') ?? false;
      _availableOnly = prefs.getBool('availableOnly') ?? false;
      _updatedRecentlyFilter = prefs.getBool('updatedRecentlyFilter') ?? false;
      _updatedRecentlyDays = prefs.getInt('updatedRecentlyDays') ?? 7;
      _typeFilter = prefs.getString('typeFilter') ?? 'all';
      _viewMode = prefs.getString('viewMode') ?? 'grid';
      _genreSidebarOpen = prefs.getBool('genreSidebarOpen') ?? true;
      _settingsPanelOpen = prefs.getBool('settingsPanelOpen') ?? false;
      _cardSizeNotifier.value = prefs.getDouble('cardSize') ?? 1.0;
      _favoritesOnly = prefs.getBool('favoritesOnly') ?? false;
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
      await prefs.setInt('updatedRecentlyDays', _updatedRecentlyDays);
      await prefs.setString('typeFilter', _typeFilter);
      await prefs.setString('viewMode', _viewMode);
      await prefs.setBool('genreSidebarOpen', _genreSidebarOpen);
      await prefs.setBool('settingsPanelOpen', _settingsPanelOpen);
      await prefs.setDouble('cardSize', _cardSizeNotifier.value);
      await prefs.setBool('favoritesOnly', _favoritesOnly);
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

  Future<void> _fetchApps({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    setState(() {
      if (!silent) _isLoading = true;
      _fetchError = null;
      if (!silent) _downloadProgress = -1.0;
    });
    try {
      final apps = await fetchAppsFromDb(
        'smb://100.95.32.89/ssd_internal/downloads/pico4/apps/apps.db',
        forceRefresh: forceRefresh,
        onProgress: silent
            ? null
            : (p) => setState(() => _downloadProgress = p),
      );
      setState(() {
        _apps = apps;
        _refilter();
      });
    } catch (e) {
      debugPrint('Error fetching apps from DB: $e');
      if (!silent) setState(() => _fetchError = e.toString());
    } finally {
      setState(() {
        if (!silent) _isLoading = false;
        if (!silent) _downloadProgress = -1.0;
      });
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
      updatedRecentlyDays: _updatedRecentlyDays,
      typeFilter: _typeFilter,
      sortOption: _sortOption,
      favoritesOnly: _favoritesOnly,
      favoriteIds: StoreFavoritesNotifier.instance.value,
    );

    // Compute genre metadata from ALL loaded apps (unfiltered) so counts
    // reflect totals regardless of active filters.
    _cachedAvailableGenresList = filter.availableGenres(_apps);
    _cachedGenreCounts = Map.of(filter.genreCountsMap(_apps))
      ..['all genres'] = _apps.length;

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
                        : '(${displayedApps.length} / ${_apps.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              // ── Download Queue button ──────────────────────────────────
              ListenableBuilder(
                listenable: DownloadJobsNotifier.instance,
                builder: (context, _) {
                  final count = DownloadJobsNotifier.instance.activeCount;
                  return DownloadQueueBadge(
                    count: count,
                    child: IconButton(
                      icon: const Icon(Icons.downloading),
                      tooltip: tr('Download Queue'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DownloadQueueScreen(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(_settingsPanelOpen ? Icons.tune : Icons.tune),
                onPressed: () => setState(() {
                  _settingsPanelOpen = !_settingsPanelOpen;
                  _savePreferences();
                }),
                tooltip: _settingsPanelOpen ? 'Close Settings' : 'Settings',
              ),
              const SizedBox(width: 8),
            ],
          ),
          // body contents
          body: Stack(
            children: [
              Positioned.fill(
                child: _showInstalledApps
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
                            favoritesOnly: _favoritesOnly,
                            onFavoritesOnlyChanged: (v) => setState(() {
                              _favoritesOnly = v;
                              _refilter();
                              _savePreferences();
                            }),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                AlphaIndexColumn(
                                  apps: _apps,
                                  onLetterTap: (letter) =>
                                      _onAlphaLetterTap(letter, displayedApps),
                                ),
                                if (_genreSidebarOpen)
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
                                                if (_viewMode ==
                                                    'master_detail') {
                                                  return _buildMasterDetailView(
                                                    displayedApps,
                                                  );
                                                }
                                                return _AppGrid(
                                                  key: _appGridKey,
                                                  apps: displayedApps,
                                                  apiUrl: _kApiUrl,
                                                  constraints: constraints,
                                                  cardSizeMultiplier: cardSize,
                                                  cardSizeNotifier:
                                                      _cardSizeNotifier,
                                                  onRefresh: () => _fetchApps(
                                                    forceRefresh: true,
                                                    silent: true,
                                                  ),
                                                  onSwitchToMasterDetail: () =>
                                                      setState(() {
                                                        _viewMode =
                                                            'master_detail';
                                                        _cardSizeNotifier
                                                                .value =
                                                            1.0;
                                                        _savePreferences();
                                                      }),
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
              ),
              // ── Dismiss overlay when settings panel is open ─────────────
              if (_settingsPanelOpen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _settingsPanelOpen = false;
                      _savePreferences();
                    }),
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
              // ── Settings side panel overlay ─────────────────────────────
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: SettingsSidePanel(
                  isOpen: _settingsPanelOpen,
                  onToggle: () => setState(() {
                    _settingsPanelOpen = !_settingsPanelOpen;
                    _savePreferences();
                  }),
                  ovrportFilter: _ovrportFilter,
                  onOvrportFilterChanged: (v) => setState(() {
                    _ovrportFilter = v;
                    _refilter();
                    _savePreferences();
                  }),
                  availableOnly: _availableOnly,
                  onAvailableOnlyChanged: (v) => setState(() {
                    _availableOnly = v;
                    _refilter();
                    _savePreferences();
                  }),
                  updatedRecentlyFilter: _updatedRecentlyFilter,
                  onUpdatedRecentlyFilterChanged: (v) => setState(() {
                    _updatedRecentlyFilter = v;
                    _refilter();
                    _savePreferences();
                  }),
                  updatedRecentlyDays: _updatedRecentlyDays,
                  onUpdatedRecentlyDaysChanged: (v) => setState(() {
                    _updatedRecentlyDays = v;
                    _refilter();
                    _savePreferences();
                  }),
                  onReloadDatabase: () => _fetchApps(forceRefresh: true),
                  onOpenInstalledApps: () {
                    setState(() {
                      _settingsPanelOpen = false;
                      _showInstalledApps = true;
                    });
                    _savePreferences();
                  },
                  onOpenAppUpdater: () {
                    setState(() => _settingsPanelOpen = false);
                    _savePreferences();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppUpdaterScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
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
      left: RefreshIndicator(
        onRefresh: () => _fetchApps(forceRefresh: true, silent: true),
        displacement: 60,
        child: ListView.separated(
          controller: _masterDetailScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          addAutomaticKeepAlives: false,
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
      ),
      right: AppDetailPanel(app: selectedApp, apiUrl: _kApiUrl),
    );
  }

  // ── Alphabet index navigation ───────────────────────────────────────────────

  void _onAlphaLetterTap(String letter, List<dynamic> apps) {
    final index = findFirstIndexForLetter(apps, letter);
    if (index < 0) return;

    if (_viewMode == 'master_detail') {
      if (!_masterDetailScrollController.hasClients) return;
      // Approximate item height: ListTile with vertical padding 8 each side
      // gives ~80px content height; separator is 8px.
      const double itemHeight = 80.0;
      const double separatorHeight = 8.0;
      const double topPadding = 16.0;
      final double offset = topPadding + index * (itemHeight + separatorHeight);
      _masterDetailScrollController.jumpTo(
        offset.clamp(
          _masterDetailScrollController.position.minScrollExtent,
          _masterDetailScrollController.position.maxScrollExtent,
        ),
      );
    } else {
      _appGridKey.currentState?.jumpToIndex(index);
    }
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
  final ValueNotifier<double> cardSizeNotifier;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onSwitchToMasterDetail;

  const _AppGrid({
    super.key,
    required this.apps,
    required this.apiUrl,
    required this.constraints,
    required this.cardSizeNotifier,
    this.cardSizeMultiplier = 1.0,
    this.onRefresh,
    this.onSwitchToMasterDetail,
  });

  @override
  State<_AppGrid> createState() => _AppGridState();
}

class _AppGridState extends State<_AppGrid> {
  final ScrollController _scrollController = ScrollController();
  bool _showFab = false;
  bool _sliderVisible = true;
  Timer? _scrollStopTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 300;
      if (show != _showFab) setState(() => _showFab = show);

      // Hide slider while scrolling; reappear after scrolling stops.
      if (_sliderVisible) setState(() => _sliderVisible = false);
      _scrollStopTimer?.cancel();
      _scrollStopTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _sliderVisible = true);
      });
    });
  }

  @override
  void dispose() {
    _scrollStopTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Instantly scrolls the grid so that the item at [index] is at the top.
  void jumpToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final w = widget.constraints.maxWidth;
    final int baseCount = w > 1200
        ? 5
        : w > 800
        ? 4
        : 2;
    final int crossAxisCount = (baseCount / widget.cardSizeMultiplier)
        .round()
        .clamp(1, 10);

    const double hPad = 24.0;
    const double spacing = 24.0;
    const double aspectRatio = 0.75;

    final double usableWidth = w - 2 * hPad - (crossAxisCount - 1) * spacing;
    final double itemWidth = usableWidth / crossAxisCount;
    final double itemHeight = itemWidth / aspectRatio;
    final double rowHeight = itemHeight + spacing;

    final int rowIndex = index ~/ crossAxisCount;
    final double offset = hPad + rowIndex * rowHeight;

    _scrollController.jumpTo(
      offset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      ),
    );
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
        RefreshIndicator(
          onRefresh: widget.onRefresh ?? () async {},
          displacement: 60,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
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
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: _sliderVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_sliderVisible,
                  child: ValueListenableBuilder<double>(
                    valueListenable: widget.cardSizeNotifier,
                    builder: (ctx, cardSize, _) => Container(
                      width: 160,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: Theme.of(
                            ctx,
                          ).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: SliderTheme(
                        data: SliderTheme.of(ctx).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Theme.of(
                            ctx,
                          ).colorScheme.primary.withValues(alpha: 0.7),
                          inactiveTrackColor: Theme.of(
                            ctx,
                          ).colorScheme.onSurface.withValues(alpha: 0.18),
                          thumbColor: Theme.of(ctx).colorScheme.primary,
                        ),
                        child: Slider(
                          value: cardSize,
                          min: 0.5,
                          max: 2.0,
                          divisions: 6,
                          onChanged: (v) => widget.cardSizeNotifier.value = v,
                          onChangeEnd: (v) {
                            if (v <= 0.5) {
                              widget.onSwitchToMasterDetail?.call();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
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
            ],
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
