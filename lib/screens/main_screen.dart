import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db_service.dart';
import '../utils/formatters.dart';
import '../utils/localization.dart';
import '../widgets/adjustable_split_view.dart';
import '../widgets/app_card.dart';
import '../widgets/app_detail_panel.dart';
import '../widgets/filter_dropdown.dart';

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

  Future<void> _fetchApps() async {
    setState(() {
      _isLoading = true;
      _downloadProgress = -1.0;
    });
    try {
      final smbApps = await fetchAppsFromDb(
        "smb://100.95.32.89/ssd_internal/downloads/pico4/apps/apps.db",
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
    final Set<String> categories = {'All Categories'};
    for (var app in _apps) {
      final catString =
          (((app['categories'] ?? app['category']) ?? app['category']) ?? '')
              .toString();
      if (catString.isNotEmpty) {
        final splits = catString.split(',');
        for (var c in splits) {
          final trimmed = c.trim();
          if (trimmed.isNotEmpty) {
            categories.add(trimmed);
          }
        }
      }
    }
    final sortedList = categories.toList();
    sortedList.sort((a, b) {
      if (a == 'All Categories') return -1;
      if (b == 'All Categories') return 1;
      return a.compareTo(b);
    });
    return sortedList;
  }

  int _getCategoryCount(String category) {
    if (category == 'All Categories') return _apps.length;
    int count = 0;
    final catLower = category.toLowerCase();
    for (var app in _apps) {
      final catString =
          (((app['categories'] ?? app['category']) ?? app['category']) ?? '')
              .toString()
              .toLowerCase();
      if (catString.isNotEmpty) {
        final splits = catString.split(',');
        for (var c in splits) {
          if (c.trim() == catLower) {
            count++;
            break; // A single app shouldn't be counted twice for the same category
          }
        }
      }
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
      final name = (((app['name'] ?? app['title']) ?? app['title']) ?? '')
          .toString()
          .toLowerCase();
      final category =
          (((app['categories'] ?? app['category']) ?? app['category']) ?? '')
              .toString()
              .toLowerCase();

      final query = _searchQuery.toLowerCase();
      String allTagsString = '';
      if (app['tags'] != null) {
        final tagsStr = app['tags'].toString();
        allTagsString = tagsStr.toLowerCase();
      }

      final matchesSearch =
          name.contains(query) ||
          category.contains(query) ||
          allTagsString.contains(query);

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
      final nameA = (a['name'] ?? a['title'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? b['title'] ?? '').toString().toLowerCase();

      if (_sortOption == 'Name (A-Z)') {
        return nameA.compareTo(nameB);
      } else if (_sortOption == 'Name (Z-A)') {
        return nameB.compareTo(nameA);
      } else if (_sortOption == 'Rating (High to Low)') {
        final scoreA = parseRating(a['user_rating'] ?? a['rating']);
        final scoreB = parseRating(b['user_rating'] ?? b['rating']);
        return scoreB.compareTo(scoreA);
      } else if (_sortOption == 'Rating (Low to High)') {
        final scoreA = parseRating(a['user_rating'] ?? a['rating']);
        final scoreB = parseRating(b['user_rating'] ?? b['rating']);
        return scoreA.compareTo(scoreB);
      } else if (_sortOption == 'Size (Large to Small)') {
        final sizeA = getAppSize(a);
        final sizeB = getAppSize(b);
        return sizeB.compareTo(sizeA);
      } else if (_sortOption == 'Size (Small to Large)') {
        final sizeA = getAppSize(a);
        final sizeB = getAppSize(b);
        return sizeA.compareTo(sizeB);
      }
      return 0;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    elevation: 2,
                    side: BorderSide.none,
                    selectedBackgroundColor: Theme.of(
                      context,
                    ).primaryColor.withAlpha(40),
                    selectedForegroundColor: Theme.of(context).primaryColor,
                  ),
                  segments: [
                    ButtonSegment(
                      value: 'all',
                      icon: Tooltip(
                        message: tr('All'),
                        child: Icon(Icons.apps),
                      ),
                    ),
                    ..._availableAppTypes.map((type) {
                      IconData iconData;
                      String titleStr;
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
                        icon: Tooltip(
                          message: tr(titleStr),
                          child: Icon(iconData),
                        ),
                      );
                    }),
                  ],
                  selected: {_typeFilter},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _typeFilter = newSelection.first;
                    });
                  },
                ),
                SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: SearchAnchor(
                      isFullScreen: false,
                      searchController: _searchController,
                      viewConstraints: BoxConstraints(maxHeight: 300),
                      builder:
                          (BuildContext context, SearchController controller) {
                            return Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(20),
                              child: TextField(
                                controller: controller,
                                onTap: () => controller.openView(),
                                onChanged: (_) => controller.openView(),
                                onSubmitted: (value) {
                                  _saveSearchHistory(value);
                                  controller.closeView(value);
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search apps...',
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).cardColor,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 0,
                                    horizontal: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                      suggestionsBuilder:
                          (BuildContext context, SearchController controller) {
                            final String query = controller.text.toLowerCase();
                            if (query.isEmpty) {
                              final List<Widget> historyItems = _searchHistory
                                  .map((String historyItem) {
                                    return ListTile(
                                      leading: Icon(Icons.history),
                                      title: Text(historyItem),
                                      onTap: () {
                                        controller.closeView(historyItem);
                                        _saveSearchHistory(historyItem);
                                      },
                                    );
                                  })
                                  .toList();

                              if (historyItems.isNotEmpty) {
                                historyItems.add(
                                  ListTile(
                                    leading: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    title: Text(
                                      tr('Clear history'),
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    onTap: () {
                                      _clearSearchHistory();
                                      controller.closeView('');
                                      Future.delayed(
                                        Duration(milliseconds: 50),
                                        () => controller.openView(),
                                      );
                                    },
                                  ),
                                );
                              }
                              return historyItems;
                            }

                            Set<String> suggestions = {};
                            for (var app in _apps) {
                              final name = (app['name'] ?? app['title'] ?? '')
                                  .toString();
                              if (name.toLowerCase().contains(query)) {
                                suggestions.add(name);

                                // Also suggest individual words from the app name for auto-completion inspiration
                                final words = name.split(RegExp(r'\s+'));
                                for (var w in words) {
                                  if (w.length > 2 &&
                                      w.toLowerCase().startsWith(query)) {
                                    suggestions.add(w);
                                  }
                                }
                              }

                              final categoryStr =
                                  (app['categories'] ?? app['category'] ?? '')
                                      .toString();
                              if (categoryStr.isNotEmpty) {
                                final cats = categoryStr
                                    .replaceAll(RegExp(r'[\[\]"]'), '')
                                    .split(',');
                                for (var c in cats) {
                                  if (c.trim().toLowerCase().contains(query)) {
                                    suggestions.add(c.trim());
                                  }
                                }
                              }

                              final tagsStr = (app['tags'] ?? app['tag'] ?? '')
                                  .toString();
                              if (tagsStr.isNotEmpty) {
                                final tags = tagsStr
                                    .replaceAll(RegExp(r'[\[\]"]'), '')
                                    .split(',');
                                for (var t in tags) {
                                  if (t.trim().toLowerCase().contains(query)) {
                                    suggestions.add(t.trim());
                                  }
                                }
                              }
                            }

                            return suggestions.take(10).map((
                              String suggestion,
                            ) {
                              return ListTile(
                                leading: Icon(Icons.search),
                                title: Text(suggestion),
                                onTap: () {
                                  controller.closeView(suggestion);
                                  _saveSearchHistory(suggestion);
                                },
                              );
                            });
                          },
                    ),
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(60.0),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    FilterDropdown(
                      value: _categoryFilter,
                      icon: Icons.category,
                      items: _availableCategories.map((String category) {
                        int count = _getCategoryCount(category);
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(
                            category == 'All Categories'
                                ? category
                                : '$category ($count)',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _categoryFilter = value;
                          });
                        }
                      },
                    ),
                    SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('Ovrport Only'),
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 4),
                        Switch(
                          value: _ovrportFilter,
                          onChanged: (bool value) {
                            setState(() {
                              _ovrportFilter = value;
                            });
                          },
                        ),
                      ],
                    ),
                    Spacer(),
                    SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withAlpha(20),
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
                            child: Icon(Icons.grid_view),
                          ),
                        ),
                        ButtonSegment(
                          value: 'master_detail',
                          icon: Tooltip(
                            message: tr('Master Detail'),
                            child: Icon(Icons.vertical_split),
                          ),
                        ),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _viewMode = newSelection.first;
                        });
                      },
                    ),
                    SizedBox(width: 16),
                    FilterDropdown(
                      value: _sortOption,
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
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _sortOption = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    '(${displayedApps.length})',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: isGreekNotifier,
                builder: (context, isGreek, child) {
                  return IconButton(
                    icon: Text(
                      isGreek ? 'GR' : 'EN',
                      style: TextStyle(
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
                icon: Icon(Icons.refresh),
                onPressed: _fetchApps,
                tooltip: tr('Refresh Apps'),
              ),
              SizedBox(width: 16),
            ],
          ),
          body: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_downloadProgress < 0)
                        CircularProgressIndicator()
                      else
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            value: _downloadProgress,
                          ),
                        ),
                      SizedBox(height: 16),
                      Text(
                        _downloadProgress < 0
                            ? 'Fetching database...'
                            : 'Fetching database... ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (_viewMode == 'master_detail') {
                      return _buildMasterDetailView(
                        context,
                        constraints,
                        displayedApps,
                      );
                    }

                    int crossAxisCount = constraints.maxWidth > 1200
                        ? 5
                        : constraints.maxWidth > 800
                        ? 4
                        : 2;

                    return GridView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.75, // Taller covers
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                      ),
                      itemCount: displayedApps.length,
                      itemBuilder: (context, index) {
                        final app = displayedApps[index];
                        return AppCard(app: app, apiUrl: _apiUrl);
                      },
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
        padding: EdgeInsets.all(16),
        itemCount: displayedApps.length,
        separatorBuilder: (context, index) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          final app = displayedApps[index];
          final isSelected = index == _selectedMasterDetailIndex;

          final isGreek = isGreekNotifier.value;
          final desc = isGreek
              ? (app['short_description_gr'] ?? app['description'] ?? '')
              : (app['short_description'] ?? app['description'] ?? '');

          final imgUrl = app['thumbnail_url'] ?? app['preview_photo'];

          return ListTile(
            selected: isSelected,
            selectedTileColor: Theme.of(context).primaryColor.withAlpha(25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: app['image'] != null
                  ? Image.network(
                      '$_apiUrl/files/image?path=${Uri.encodeComponent(app['image'])}',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.withAlpha(51),
                        child: Icon(Icons.videogame_asset),
                      ),
                    )
                  : imgUrl != null
                  ? Image.network(
                      imgUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.withAlpha(51),
                        child: Icon(Icons.videogame_asset),
                      ),
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey.withAlpha(51),
                      child: Icon(Icons.videogame_asset),
                    ),
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
              style: TextStyle(fontSize: 13),
            ),
            onTap: () {
              setState(() {
                _selectedMasterDetailIndex = index;
              });
            },
          );
        },
      ),
      right: AppDetailPanel(app: selectedApp, apiUrl: _apiUrl),
    );
  }
}
