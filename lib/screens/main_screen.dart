import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db_service.dart';
import '../utils/formatters.dart';
import '../utils/localization.dart';
import '../widgets/adjustable_split_view.dart';
import '../widgets/app_card.dart';
import '../widgets/app_detail_panel.dart';
import '../widgets/filter_dropdown.dart';

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// A single row in the master-detail list.
class _AppListTile extends StatelessWidget {
  final dynamic app;
  final bool isSelected;
  final String apiUrl;
  final VoidCallback onTap;

  const _AppListTile({
    required this.app,
    required this.isSelected,
    required this.apiUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGreek = isGreekNotifier.value;
    final desc = isGreek
        ? (app['short_description_gr'] ?? app['description'] ?? '')
        : (app['short_description'] ?? app['description'] ?? '');
    final imgUrl = app['thumbnail_url'] ?? app['preview_photo'];

    Widget leadingImage;
    if (app['image'] != null) {
      leadingImage = Image.network(
        '$apiUrl/files/image?path=${Uri.encodeComponent(app['image'])}',
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholderIcon(),
      );
    } else if (imgUrl != null) {
      leadingImage = Image.network(
        imgUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholderIcon(),
      );
    } else {
      leadingImage = _placeholderIcon();
    }

    return ListTile(
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withAlpha(25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: leadingImage,
      ),
      title: Text(
        app['name'] ?? app['title'] ?? 'Unknown',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        desc,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      onTap: onTap,
    );
  }

  Widget _placeholderIcon() => Container(
    width: 64,
    height: 64,
    color: Colors.grey.withAlpha(51),
    child: const Icon(Icons.videogame_asset),
  );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  // Point this to your PC's Python FastAPI local network IP address
  final String _apiUrl = 'http://192.168.1.17:8001/api';

  List<dynamic> _apps = [];
  bool _isLoading = false;
  double _downloadProgress = -1.0;

  String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';
  String _categoryFilter = 'All Categories';
  bool _ovrportFilter = false;
  String _typeFilter = 'all';

  String _viewMode = 'grid'; // 'grid' or 'master_detail'
  int _selectedMasterDetailIndex = 0;

  List<String> _searchHistory = [];
  final SearchController _searchController = SearchController();

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _fetchApps();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('searchHistory') ?? [];
    });
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('searchHistory') ?? [];
    history.remove(query);
    history.insert(0, query);
    if (history.length > 4) {
      history = history.sublist(0, 4);
    }
    await prefs.setStringList('searchHistory', history);
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('searchHistory');
    setState(() {
      _searchHistory = [];
    });
  }

  Future<void> _fetchApps({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _downloadProgress = -1.0;
    });
    try {
      final smbApps = await fetchAppsFromDb(
        "smb://100.95.32.89/ssd_internal/downloads/pico4/apps/apps.db",
        forceRefresh: forceRefresh,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );
      setState(() {
        _apps = smbApps;
      });
    } catch (e) {
      debugPrint('Error fetching apps from DB: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _downloadProgress = -1.0;
      });
    }
  }

  List<String> get _availableCategories {
    final categories = <String>{'All Categories'};
    for (final app in _apps) {
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

  int _getCategoryCount(String category) {
    if (category == 'All Categories') return _apps.length;
    final catLower = category.toLowerCase();
    int count = 0;
    for (final app in _apps) {
      final cats = (app['categories'] ?? app['category'] ?? '')
          .toString()
          .toLowerCase()
          .split(',');
      if (cats.any((c) => c.trim() == catLower)) count++;
    }
    return count;
  }

  List<String> get _availableAppTypes {
    final types = _apps
        .map((app) {
          final type = app['app_type']?.toString().toLowerCase();
          if (type != null && type.isNotEmpty) {
            return type;
          }
          // Fallback if not specified
          return 'app';
        })
        .toSet()
        .toList();
    types.sort();
    return types;
  }

  List<dynamic> get _filteredAndSortedApps {
    List<dynamic> filtered = _apps.where((app) {
      final name = (app['name'] ?? app['title'] ?? '').toString().toLowerCase();
      final category = (app['categories'] ?? app['category'] ?? '')
          .toString()
          .toLowerCase();
      final tags = (app['tags'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      final matchesSearch =
          name.contains(query) ||
          category.contains(query) ||
          tags.contains(query);

      final matchesCategory =
          _categoryFilter == 'All Categories' ||
          category.contains(_categoryFilter.toLowerCase());

      final matchesOvrport =
          !_ovrportFilter ||
          (app['ovrport'] == 1 ||
              app['ovrport'] == true ||
              app['ovrport'] == '1' ||
              app['ovrport'] == 'true');

      final String appType = app['app_type']?.toString().toLowerCase() ?? 'app';
      final matchesType = _typeFilter == 'all' || _typeFilter == appType;

      return matchesSearch && matchesCategory && matchesOvrport && matchesType;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case 'Name (A-Z)':
          return (a['name'] ?? a['title'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (b['name'] ?? b['title'] ?? '').toString().toLowerCase(),
              );
        case 'Name (Z-A)':
          return (b['name'] ?? b['title'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (a['name'] ?? a['title'] ?? '').toString().toLowerCase(),
              );
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
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final displayedApps = _filteredAndSortedApps;

    return ValueListenableBuilder<bool>(
      valueListenable: isGreekNotifier,
      builder: (context, isGreek, child) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Text(
                  "Liako's App Store",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                ),
                SizedBox(width: 16),
                _AppTypeSegmentedButton(
                  availableTypes: _availableAppTypes,
                  selected: _typeFilter,
                  onChanged: (t) => setState(() => _typeFilter = t),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: _AppSearchField(
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
            bottom: _FilterBar(
              categoryFilter: _categoryFilter,
              availableCategories: _availableCategories,
              getCategoryCount: _getCategoryCount,
              ovrportFilter: _ovrportFilter,
              viewMode: _viewMode,
              sortOption: _sortOption,
              onCategoryChanged: (v) {
                if (v != null) setState(() => _categoryFilter = v);
              },
              onOvrportChanged: (v) => setState(() => _ovrportFilter = v),
              onViewModeChanged: (v) => setState(() => _viewMode = v),
              onSortChanged: (v) {
                if (v != null) setState(() => _sortOption = v);
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
                builder: (context, isGreek, child) {
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
                onPressed: () {
                  themeNotifier.value = isDarkMode
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (_viewMode == 'master_detail') {
                      return _buildMasterDetailView(
                        context,
                        constraints,
                        displayedApps,
                      );
                    }
                    return _AppGrid(
                      apps: displayedApps,
                      apiUrl: _apiUrl,
                      constraints: constraints,
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildMasterDetailView(
    BuildContext context,
    BoxConstraints constraints,
    List<dynamic> displayedApps,
  ) {
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
          final app = displayedApps[index];
          return _AppListTile(
            app: app,
            isSelected: index == _selectedMasterDetailIndex,
            apiUrl: _apiUrl,
            onTap: () => setState(() => _selectedMasterDetailIndex = index),
          );
        },
      ),
      right: AppDetailPanel(app: selectedApp, apiUrl: _apiUrl),
    );
  }
}

// ── AppBar filter bar (bottom PreferredSize) ──────────────────────────────────

class _FilterBar extends StatelessWidget implements PreferredSizeWidget {
  final String categoryFilter;
  final List<String> availableCategories;
  final int Function(String) getCategoryCount;
  final bool ovrportFilter;
  final String viewMode;
  final String sortOption;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<bool> onOvrportChanged;
  final ValueChanged<String> onViewModeChanged;
  final ValueChanged<String?> onSortChanged;

  const _FilterBar({
    required this.categoryFilter,
    required this.availableCategories,
    required this.getCategoryCount,
    required this.ovrportFilter,
    required this.viewMode,
    required this.sortOption,
    required this.onCategoryChanged,
    required this.onOvrportChanged,
    required this.onViewModeChanged,
    required this.onSortChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          FilterDropdown(
            value: categoryFilter,
            icon: Icons.category,
            items: availableCategories.map((String category) {
              final count = getCategoryCount(category);
              return DropdownMenuItem<String>(
                value: category,
                child: Text(
                  category == 'All Categories'
                      ? category
                      : '$category ($count)',
                ),
              );
            }).toList(),
            onChanged: onCategoryChanged,
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('Ovrport Only'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              Switch(value: ovrportFilter, onChanged: onOvrportChanged),
            ],
          ),
          const Spacer(),
          SegmentedButton<String>(
            style: SegmentedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor.withAlpha(20),
              selectedBackgroundColor: Theme.of(
                context,
              ).primaryColor.withAlpha(40),
              selectedForegroundColor: Theme.of(context).primaryColor,
            ),
            segments: [
              ButtonSegment(
                value: 'grid',
                icon: Tooltip(
                  message: tr('Grid View'),
                  child: const Icon(Icons.grid_view),
                ),
              ),
              ButtonSegment(
                value: 'master_detail',
                icon: Tooltip(
                  message: tr('Master Detail'),
                  child: const Icon(Icons.vertical_split),
                ),
              ),
            ],
            selected: {viewMode},
            onSelectionChanged: (Set<String> sel) =>
                onViewModeChanged(sel.first),
          ),
          const SizedBox(width: 16),
          FilterDropdown(
            value: sortOption,
            icon: Icons.sort,
            items: [
              DropdownMenuItem(
                value: 'Name (A-Z)',
                child: Text(tr('Name (A-Z)')),
              ),
              DropdownMenuItem(
                value: 'Name (Z-A)',
                child: Text(tr('Name (Z-A)')),
              ),
              DropdownMenuItem(
                value: 'Rating (High to Low)',
                child: Text(tr('Rating (High to Low)')),
              ),
              DropdownMenuItem(
                value: 'Rating (Low to High)',
                child: Text(tr('Rating (Low to High)')),
              ),
              DropdownMenuItem(
                value: 'Size (Large to Small)',
                child: Text(tr('Size (Large to Small)')),
              ),
              DropdownMenuItem(
                value: 'Size (Small to Large)',
                child: Text(tr('Size (Small to Large)')),
              ),
            ],
            onChanged: onSortChanged,
          ),
        ],
      ),
    );
  }
}

// ── App-type segmented button ─────────────────────────────────────────────────

class _AppTypeSegmentedButton extends StatelessWidget {
  final List<String> availableTypes;
  final String selected;
  final ValueChanged<String> onChanged;

  const _AppTypeSegmentedButton({
    required this.availableTypes,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        elevation: 2,
        side: BorderSide.none,
        selectedBackgroundColor: Theme.of(context).primaryColor.withAlpha(40),
        selectedForegroundColor: Theme.of(context).primaryColor,
      ),
      segments: [
        ButtonSegment(
          value: 'all',
          icon: Tooltip(message: tr('All'), child: const Icon(Icons.apps)),
        ),
        ...availableTypes.map((type) {
          final IconData iconData;
          final String titleStr;
          if (type == 'game') {
            iconData = Icons.sports_esports;
            titleStr = 'Games';
          } else if (type == 'app') {
            iconData = Icons.developer_board;
            titleStr = 'Apps';
          } else {
            iconData = Icons.extension;
            titleStr = type[0].toUpperCase() + type.substring(1);
          }
          return ButtonSegment(
            value: type,
            icon: Tooltip(message: tr(titleStr), child: Icon(iconData)),
          );
        }),
      ],
      selected: {selected},
      onSelectionChanged: (Set<String> sel) => onChanged(sel.first),
    );
  }
}

// ── Search field with autocomplete suggestions ────────────────────────────────

class _AppSearchField extends StatelessWidget {
  final List<dynamic> apps;
  final List<String> searchHistory;
  final SearchController controller;
  final Future<void> Function(String) onSaveHistory;
  final VoidCallback onClearHistory;

  const _AppSearchField({
    required this.apps,
    required this.searchHistory,
    required this.controller,
    required this.onSaveHistory,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      isFullScreen: false,
      searchController: controller,
      viewConstraints: const BoxConstraints(maxHeight: 300),
      builder: (BuildContext context, SearchController ctl) {
        return Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(20),
          child: TextField(
            controller: ctl,
            onTap: () => ctl.openView(),
            onChanged: (_) => ctl.openView(),
            onSubmitted: (value) {
              onSaveHistory(value);
              ctl.closeView(value);
            },
            decoration: InputDecoration(
              hintText: 'Search apps...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
            ),
          ),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController ctl) {
        final String query = ctl.text.toLowerCase();
        if (query.isEmpty) {
          final List<Widget> historyItems = searchHistory.map((String item) {
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(item),
              onTap: () {
                ctl.closeView(item);
                onSaveHistory(item);
              },
            );
          }).toList();

          if (historyItems.isNotEmpty) {
            historyItems.add(
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  tr('Clear history'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  onClearHistory();
                  ctl.closeView('');
                  Future.delayed(
                    const Duration(milliseconds: 50),
                    () => ctl.openView(),
                  );
                },
              ),
            );
          }
          return historyItems;
        }

        final Set<String> suggestions = {};
        for (final app in apps) {
          final name = (app['name'] ?? app['title'] ?? '').toString();
          if (name.toLowerCase().contains(query)) {
            suggestions.add(name);
            for (final w in name.split(RegExp(r'\s+'))) {
              if (w.length > 2 && w.toLowerCase().startsWith(query)) {
                suggestions.add(w);
              }
            }
          }

          final categoryStr = (app['categories'] ?? app['category'] ?? '')
              .toString();
          for (final c in categoryStr.split(',')) {
            if (c.trim().toLowerCase().contains(query)) {
              suggestions.add(c.trim());
            }
          }

          final tagsStr = (app['tags'] ?? '').toString();
          for (final t
              in tagsStr.replaceAll(RegExp(r'[\[\]"]'), '').split(',')) {
            if (t.trim().toLowerCase().contains(query)) {
              suggestions.add(t.trim());
            }
          }
        }

        return suggestions.take(10).map((String suggestion) {
          return ListTile(
            leading: const Icon(Icons.search),
            title: Text(suggestion),
            onTap: () {
              ctl.closeView(suggestion);
              onSaveHistory(suggestion);
            },
          );
        });
      },
    );
  }
}

// ── Loading indicator ─────────────────────────────────────────────────────────

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

// ── Responsive app grid ───────────────────────────────────────────────────────

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
      itemBuilder: (context, index) {
        return AppCard(app: apps[index], apiUrl: apiUrl);
      },
    );
  }
}
