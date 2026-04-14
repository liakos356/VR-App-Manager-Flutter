import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'install_service.dart';
import 'db_service.dart';

double _parseRating(dynamic rating) {
  if (rating == null) return 0.0;
  double r = 0.0;
  if (rating is num) {
    r = rating.toDouble();
  } else {
    r = double.tryParse(rating.toString()) ?? 0.0;
  }
  if (r > 10) return r / 20.0; // out of 100 -> out of 5
  if (r > 5) return r / 2.0; // out of 10 -> out of 5
  return r;
}

String _formatBytes(dynamic bytes) {
  if (bytes == null) return 'Unknown Size';
  int bytesInt = 0;
  if (bytes is num) {
    bytesInt = bytes.toInt();
  } else {
    bytesInt = int.tryParse(bytes.toString()) ?? 0;
  }
  if (bytesInt <= 0) return 'Unknown Size';

  if (bytesInt < 1024 * 1024) {
    return '${(bytesInt / 1024).toStringAsFixed(1)} KB';
  } else if (bytesInt < 1024 * 1024 * 1024) {
    return '${(bytesInt / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else {
    return '${(bytesInt / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

int _getAppSize(dynamic app) {
  if (app == null) return 0;
  int sizeApk = _getApkSize(app);
  int sizeObb = _getObbSize(app);

  int total = sizeApk + sizeObb;
  if (total == 0 && app['size_bytes'] != null) {
    total = int.tryParse(app['size_bytes'].toString()) ?? 0;
  }
  return total;
}

int _getApkSize(dynamic app) {
  if (app == null || app['size_bytes_apk'] == null) return 0;
  return int.tryParse(app['size_bytes_apk'].toString()) ?? 0;
}

int _getObbSize(dynamic app) {
  if (app == null || app['size_bytes_obb'] == null) return 0;
  return int.tryParse(app['size_bytes_obb'].toString()) ?? 0;
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() {
  runApp(const AppManagerApp());
}

class AppManagerApp extends StatelessWidget {
  const AppManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
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
            colorScheme: const ColorScheme.light(
              primary: Colors.purple,
              secondary: Colors.pink,
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
            scaffoldBackgroundColor: const Color(0xFF111827),
            cardColor: const Color(0xFF1F2937),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1F2937),
              foregroundColor: Colors.white,
            ),
            colorScheme: const ColorScheme.dark(
              primary: Colors.purpleAccent,
              secondary: Colors.pinkAccent,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1F2937),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Point this to your PC's Python FastAPI local network IP address
  final String _apiUrl = 'http://192.168.1.17:8001/api';

  List<dynamic> _apps = [];
  bool _isLoading = false;
  double _downloadProgress = -1.0;

  String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';
  String _categoryFilter = 'All Categories';
  String _tagFilter = 'All Tags';
  bool _ovrportFilter = false;

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

  List<String> get _availableTags {
    final Set<String> tagsSet = {'All Tags'};
    for (var app in _apps) {
      if (app['tags'] != null) {
        final tagsStr = app['tags'].toString();
        if (tagsStr.trim().isEmpty) continue;

        try {
          final List<dynamic> parsed = jsonDecode(tagsStr);
          for (var t in parsed) {
            final trimmed = t.toString().trim();
            if (trimmed.isNotEmpty) {
              tagsSet.add(trimmed);
            }
          }
        } catch (_) {
          final splits = tagsStr.replaceAll(RegExp(r'[\[\]"]'), '').split(',');
          for (var t in splits) {
            final trimmed = t.trim();
            if (trimmed.isNotEmpty) {
              tagsSet.add(trimmed);
            }
          }
        }
      }
    }
    final sortedList = tagsSet.toList();
    sortedList.sort((a, b) {
      if (a == 'All Tags') return -1;
      if (b == 'All Tags') return 1;
      return a.compareTo(b);
    });
    return sortedList;
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

      bool matchesTag = _tagFilter == 'All Tags';
      String allTagsString = '';
      if (app['tags'] != null) {
        final tagsStr = app['tags'].toString();
        allTagsString = tagsStr.toLowerCase();
        if (!matchesTag) {
          try {
            final List<dynamic> parsed = jsonDecode(tagsStr);
            matchesTag = parsed.any(
              (tag) => tag.toString().trim() == _tagFilter,
            );
          } catch (_) {
            final splits = tagsStr
                .replaceAll(RegExp(r'[\[\]"]'), '')
                .split(',');
            matchesTag = splits.any((tag) => tag.trim() == _tagFilter);
          }
        }
      }

      final query = _searchQuery.toLowerCase();
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

      return matchesSearch && matchesCategory && matchesTag && matchesOvrport;
    }).toList();

    filtered.sort((a, b) {
      if (_sortOption == 'Name (A-Z)') {
        return (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        );
      } else if (_sortOption == 'Name (Z-A)') {
        return (b['name'] ?? '').toString().compareTo(
          (a['name'] ?? '').toString(),
        );
      } else if (_sortOption == 'Rating (High to Low)') {
        final scoreA = _parseRating(a['user_rating']);
        final scoreB = _parseRating(b['user_rating']);
        return scoreB.compareTo(scoreA);
      } else if (_sortOption == 'Rating (Low to High)') {
        final scoreA = _parseRating(a['user_rating']);
        final scoreB = _parseRating(b['user_rating']);
        return scoreA.compareTo(scoreB);
      } else if (_sortOption == 'Size (Large to Small)') {
        final sizeA = _getAppSize(a);
        final sizeB = _getAppSize(b);
        return sizeB.compareTo(sizeA);
      } else if (_sortOption == 'Size (Small to Large)') {
        final sizeA = _getAppSize(a);
        final sizeB = _getAppSize(b);
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Pico 4 App Manager (${displayedApps.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: SizedBox(
                height: 40,
                child: SearchAnchor(
                  isFullScreen: false,
                  searchController: _searchController,
                  viewConstraints: const BoxConstraints(maxHeight: 300),
                  builder: (BuildContext context, SearchController controller) {
                    return TextField(
                      controller: controller,
                      onTap: () => controller.openView(),
                      onChanged: (_) => controller.openView(),
                      onSubmitted: (value) {
                        _saveSearchHistory(value);
                        controller.closeView(value);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search apps...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                      ),
                    );
                  },
                  suggestionsBuilder:
                      (BuildContext context, SearchController controller) {
                        final String query = controller.text.toLowerCase();
                        if (query.isEmpty) {
                          final List<Widget> historyItems = _searchHistory.map((
                            String historyItem,
                          ) {
                            return ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(historyItem),
                              onTap: () {
                                controller.closeView(historyItem);
                                _saveSearchHistory(historyItem);
                              },
                            );
                          }).toList();

                          if (historyItems.isNotEmpty) {
                            historyItems.add(
                              ListTile(
                                leading: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                title: const Text(
                                  'Clear history',
                                  style: TextStyle(color: Colors.red),
                                ),
                                onTap: () {
                                  _clearSearchHistory();
                                  controller.closeView('');
                                  Future.delayed(
                                    const Duration(milliseconds: 50),
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

                        return suggestions.take(10).map((String suggestion) {
                          return ListTile(
                            leading: const Icon(Icons.search),
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
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                _FilterDropdown(
                  value: _categoryFilter,
                  icon: Icons.category,
                  items: _availableCategories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
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
                const SizedBox(width: 16),
                _FilterDropdown(
                  value: _tagFilter,
                  icon: Icons.label,
                  items: _availableTags.map((String tag) {
                    return DropdownMenuItem<String>(
                      value: tag,
                      child: Text(tag),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _tagFilter = value;
                      });
                    }
                  },
                ),
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ovrport Only',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
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
                const Spacer(),
                _FilterDropdown(
                  value: _sortOption,
                  icon: Icons.sort,
                  items: const [
                    DropdownMenuItem(
                      value: 'Name (A-Z)',
                      child: Text('Name (A-Z)'),
                    ),
                    DropdownMenuItem(
                      value: 'Name (Z-A)',
                      child: Text('Name (Z-A)'),
                    ),
                    DropdownMenuItem(
                      value: 'Rating (High to Low)',
                      child: Text('Rating (High to Low)'),
                    ),
                    DropdownMenuItem(
                      value: 'Rating (Low to High)',
                      child: Text('Rating (Low to High)'),
                    ),
                    DropdownMenuItem(
                      value: 'Size (Large to Small)',
                      child: Text('Size (Large to Small)'),
                    ),
                    DropdownMenuItem(
                      value: 'Size (Small to Large)',
                      child: Text('Size (Small to Large)'),
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
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = isDarkMode
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchApps,
            tooltip: 'Refresh Apps',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_downloadProgress < 0)
                    const CircularProgressIndicator()
                  else
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(value: _downloadProgress),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _downloadProgress < 0
                        ? 'Fetching database...'
                        : 'Fetching database... ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 1200
                    ? 5
                    : constraints.maxWidth > 800
                    ? 4
                    : 2;

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
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
                    return _AppCard(app: app, apiUrl: _apiUrl);
                  },
                );
              },
            ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final IconData icon;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).cardColor,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double score;
  final double iconSize;

  const _StarRating({required this.score, this.iconSize = 24.0});

  @override
  Widget build(BuildContext context) {
    final starCount = score;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        IconData icon;
        if (starCount >= index + 0.75) {
          icon = Icons.star;
        } else if (starCount >= index + 0.25) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: Colors.yellow, size: iconSize);
      }),
    );
  }
}

class _AppCard extends StatefulWidget {
  final dynamic app;
  final String apiUrl;

  const _AppCard({required this.app, required this.apiUrl});

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  bool _isHovered = false;
  int _currentImageIndex = 0;

  bool _isInstalling = false;
  double _installProgress = 0.0;

  List<String> get _allImages {
    final images = <String>[];
    if (((widget.app['thumbnail_url'] ?? widget.app['preview_photo']) ??
                widget.app['preview_photo']) !=
            null &&
        ((widget.app['thumbnail_url'] ?? widget.app['preview_photo']) ??
                widget.app['preview_photo'])
            .toString()
            .isNotEmpty) {
      images.add(
        ((widget.app['thumbnail_url'] ?? widget.app['preview_photo']) ??
            widget.app['preview_photo']),
      );
    }
    if (widget.app['screenshots'] != null) {
      try {
        final decoded = jsonDecode(widget.app['screenshots']);
        if (decoded is List) {
          images.addAll(
            decoded.map((e) => e.toString()).where((e) => e.isNotEmpty),
          );
        }
      } catch (_) {}
    }
    return images;
  }

  void _showInstallBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Install ${((widget.app['name'] ?? widget.app['title']) ?? widget.app['title']) ?? 'App'}?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Do you want to send this app to your headset for installation?',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 18)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final String appId = widget.app['id']?.toString() ?? '';

                      if (appId.isEmpty) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invalid Object: App ID is empty',
                              style: TextStyle(fontSize: 16),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Starting Background Install...',
                            style: TextStyle(fontSize: 16),
                          ),
                          backgroundColor: Colors.blue,
                        ),
                      );

                      try {
                        await InstallService.installAppLocally(
                          appId: appId,
                          apkPath:
                              widget.app['file_path_apk']?.toString() ?? '',
                          obbDir: widget.app['file_path_obb']?.toString() ?? '',
                          onProgress: (progress) {
                            // Show quick feedback per step, could be noisy but helpful
                            debugPrint("Feedback: $progress");
                          },
                        );
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Installation Failed: $e',
                              style: const TextStyle(fontSize: 16),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text(
                      'Install',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetails(BuildContext context) {
    List<String> screenshots = [];
    if (widget.app['screenshots'] != null) {
      try {
        final decoded = jsonDecode(widget.app['screenshots']);
        if (decoded is List) {
          screenshots = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    List<String> tags = [];
    if (widget.app['tags'] != null) {
      final tagsStr = widget.app['tags'].toString();
      if (tagsStr.trim().isNotEmpty) {
        try {
          final List<dynamic> parsed = jsonDecode(tagsStr);
          tags = parsed
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } catch (_) {
          tags = tagsStr
              .replaceAll(RegExp(r'[\[\]"]'), '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                ((widget.app['name'] ?? widget.app['title']) ??
                        widget.app['title']) ??
                    'Unknown App',
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_allImages.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            _allImages.first,
                            width: 400,
                            height: 250,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 400,
                              height: 250,
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(
                                  Icons.vrpano,
                                  size: 80,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 400,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.vrpano,
                              size: 80,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ((widget.app['name'] ?? widget.app['title']) ??
                                      widget.app['title']) ??
                                  'Unknown App',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (_getAppSize(widget.app) > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20.0),
                                child: Text(
                                  "Size: ${_formatBytes(_getAppSize(widget.app))}${_getObbSize(widget.app) > 0 ? '\n(APK: ${_formatBytes(_getApkSize(widget.app))} + OBB: ${_formatBytes(_getObbSize(widget.app))})' : ''}",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.7),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 20),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                ((widget.app['categories'] ??
                                            widget.app['category']) ??
                                        widget.app['category']) ??
                                    'Category',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            if (widget.app['ovrport'] == 1 ||
                                widget.app['ovrport'] == true ||
                                widget.app['ovrport'] == '1' ||
                                widget.app['ovrport'] == 'true') ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Text(
                                  'Ovrport',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: tags.map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                _StarRating(
                                  score: _parseRating(
                                    ((widget.app['user_rating'] ??
                                            widget.app['rating']) ??
                                        widget.app['rating']),
                                  ),
                                  iconSize: 32,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${_parseRating(((widget.app['user_rating'] ?? widget.app['rating']) ?? widget.app['rating'])).toStringAsFixed(1).replaceAll('.0', '')}/5",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      SizedBox(
                        width: 280,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Material(
                              color: _isInstalling
                                  ? Colors.green.shade800
                                  : Colors.green.shade600,
                              clipBehavior: Clip.antiAlias,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: _isInstalling
                                    ? null
                                    : () async {
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        final String appId =
                                            widget.app['id']?.toString() ?? '';
                                        final String apkPath =
                                            widget.app['apk_path']
                                                ?.toString() ??
                                            '';
                                        final String obbDir =
                                            widget.app['obb_dir']?.toString() ??
                                            '';

                                        if (appId.isEmpty) {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Invalid Object: App ID is empty',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        setState(() {
                                          _isInstalling = true;
                                          _installProgress = 0.0;
                                        });

                                        try {
                                          await InstallService.installAppLocally(
                                            appId: appId,
                                            apkPath: apkPath,
                                            obbDir: obbDir,
                                            onProgress: (progress) {
                                              // we don't display the string progress right now
                                            },
                                            onDownloadProgress: (progress) {
                                              if (mounted) {
                                                setState(
                                                  () => _installProgress =
                                                      progress,
                                                );
                                              }
                                            },
                                          );

                                          if (mounted) {
                                            setState(() {
                                              _isInstalling = false;
                                              _installProgress = 0.0;
                                            });
                                          }
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Done',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          if (mounted) {
                                            setState(() {
                                              _isInstalling = false;
                                              _installProgress = 0.0;
                                            });
                                          }
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Install Error: $e',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                ),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                child: Stack(
                                  children: [
                                    if (_isInstalling && _installProgress > 0)
                                      Positioned.fill(
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: _installProgress.clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          child: Container(
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (!_isInstalling)
                                              const Icon(
                                                Icons.download,
                                                size: 32,
                                                color: Colors.white,
                                              )
                                            else
                                              const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 3,
                                                    ),
                                              ),
                                            const SizedBox(width: 12),
                                            Text(
                                              _isInstalling
                                                  ? 'Installing (${(_installProgress * 100).toStringAsFixed(0)}%)'
                                                  : 'Install',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (((widget.app['trailer_url'] ??
                                        widget.app['video_url']) ??
                                    widget.app['video_url']) !=
                                null) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.play_circle_fill,
                                  size: 32,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Watch Trailer',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () async {
                                  String urlString =
                                      ((widget.app['trailer_url'] ??
                                          widget.app['video_url']) ??
                                      widget.app['video_url']);
                                  if (!urlString.startsWith('http://') &&
                                      !urlString.startsWith('https://')) {
                                    urlString = 'https://$urlString';
                                  }

                                  final videoId =
                                      YoutubePlayerController.convertUrlToId(
                                        urlString,
                                      );

                                  if (videoId != null && context.mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          _TrailerDialog(videoId: videoId),
                                    );
                                  } else {
                                    final url = Uri.parse(urlString);
                                    try {
                                      await launchUrl(
                                        url,
                                        mode: LaunchMode.inAppWebView,
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not launch trailer',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (screenshots.isNotEmpty) ...[
                            Text(
                              'Screenshots',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: screenshots.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            _FullscreenImageViewer(
                                              imageUrls: screenshots,
                                              initialIndex: index,
                                            ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        screenshots[index],
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          height: 200,
                                          width: 300,
                                          color: Colors.grey[800],
                                          child: const Center(
                                            child: Icon(
                                              Icons.vrpano,
                                              size: 40,
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          Html(
                            data:
                                ((widget.app['long_description'] ??
                                        widget.app['description']) ??
                                    widget.app['description']) ??
                                'No description available.',
                            style: {
                              "body": Style(
                                fontSize: FontSize(22.0),
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.8),
                                lineHeight: LineHeight(1.6),
                                margin: Margins.zero,
                                padding: HtmlPaddings.zero,
                              ),
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _allImages;
    final hasMultipleImages = images.length > 1;

    return Card(
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: () => _showDetails(context),
          onLongPress: () => _showInstallBottomSheet(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: images.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            images[_currentImageIndex],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(
                                  Icons.vrpano,
                                  size: 64,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                          if (_isHovered && hasMultipleImages)
                            Positioned.fill(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.chevron_left,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _currentImageIndex =
                                            (_currentImageIndex - 1) %
                                            images.length;
                                        if (_currentImageIndex < 0) {
                                          _currentImageIndex += images.length;
                                        }
                                      });
                                    },
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                      shape: const CircleBorder(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _currentImageIndex =
                                            (_currentImageIndex + 1) %
                                            images.length;
                                      });
                                    },
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                      shape: const CircleBorder(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_isHovered && hasMultipleImages)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (index) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    width: _currentImageIndex == index ? 8 : 6,
                                    height: _currentImageIndex == index ? 8 : 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentImageIndex == index
                                          ? Colors.white
                                          : Colors.white54,
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(
                            Icons.vrpano,
                            size: 64,
                            color: Colors.white54,
                          ),
                        ),
                      ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: AutoSizeText(
                                ((widget.app['name'] ?? widget.app['title']) ??
                                        widget.app['title']) ??
                                    'Unknown App',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                minFontSize: 12,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_getAppSize(widget.app) > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Size: ${_formatBytes(_getAppSize(widget.app))}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            if (widget.app['ovrport'] == 1 ||
                                widget.app['ovrport'] == true ||
                                widget.app['ovrport'] == '1' ||
                                widget.app['ovrport'] == 'true')
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Ovrport',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: AutoSizeText(
                                ((widget.app['categories'] ??
                                            widget.app['category']) ??
                                        widget.app['category']) ??
                                    '',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                minFontSize: 10,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StarRating(
                            score: _parseRating(
                              ((widget.app['user_rating'] ??
                                      widget.app['rating']) ??
                                  widget.app['rating']),
                            ),
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.1,
                maxScale: 4.0,
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 100,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 40),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (_currentIndex > 0)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 60,
                  ),
                  onPressed: _previousPage,
                ),
              ),
            ),
          if (_currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 60,
                  ),
                  onPressed: _nextPage,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrailerDialog extends StatefulWidget {
  final String videoId;
  const _TrailerDialog({required this.videoId});

  @override
  State<_TrailerDialog> createState() => _TrailerDialogState();
}

class _TrailerDialogState extends State<_TrailerDialog> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: YoutubePlayer(controller: _controller),
            ),
            Positioned(
              top: -10,
              right: -10,
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.white, size: 36),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
