import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/favorites_service.dart';
import '../utils/installed_apps_cache.dart';

enum AppViewMode { list, grid, iconOnly, detailList }

enum AppSortOption { installTime, name, packageName }

enum AppSortDirection { asc, desc }

const Duration _newAppThreshold = Duration(days: 7);

class InstalledAppsScreen extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<bool>? onToggleInstalledApps;
  final ValueChanged<int>? onAppCountChanged;

  const InstalledAppsScreen({
    super.key,
    this.searchQuery = '',
    this.onToggleInstalledApps,
    this.onAppCountChanged,
  });

  @override
  State<InstalledAppsScreen> createState() => _InstalledAppsScreenState();
}

class _InstalledAppsScreenState extends State<InstalledAppsScreen> {
  List<AppInfo> _allApps = [];
  bool _isLoading = true;

  // View state
  AppViewMode _viewMode = AppViewMode.grid;
  double _baseSize = 60.0;

  // Selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedPackages = {};
  // Favorites state
  Set<String> _favoritePackages = {};
  bool _showFavoritesOnly = false;
  // Search & Filter state
  AppSortOption _sortOption = AppSortOption.installTime;
  AppSortDirection _sortDirection = AppSortDirection.desc;

  // Cached SharedPreferences instance
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      _loadInstalledAppsPrefs(prefs);
    });
    _loadInstalledApps();
    _loadFavorites();
  }

  void _loadInstalledAppsPrefs(SharedPreferences prefs) {
    if (!mounted) return;
    setState(() {
      _baseSize = prefs.getDouble('ia_baseSize') ?? 60.0;
      final viewModeStr = prefs.getString('ia_viewMode') ?? 'grid';
      _viewMode = AppViewMode.values.firstWhere(
        (e) => e.name == viewModeStr,
        orElse: () => AppViewMode.grid,
      );
      final sortOptionStr = prefs.getString('ia_sortOption') ?? 'installTime';
      _sortOption = AppSortOption.values.firstWhere(
        (e) => e.name == sortOptionStr,
        orElse: () => AppSortOption.installTime,
      );
      final sortDirStr = prefs.getString('ia_sortDirection') ?? 'desc';
      _sortDirection = sortDirStr == 'asc'
          ? AppSortDirection.asc
          : AppSortDirection.desc;
      _showFavoritesOnly = prefs.getBool('ia_showFavoritesOnly') ?? false;
    });
  }

  Future<void> _saveInstalledAppsPrefs() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setDouble('ia_baseSize', _baseSize);
    await prefs.setString('ia_viewMode', _viewMode.name);
    await prefs.setString('ia_sortOption', _sortOption.name);
    await prefs.setString(
      'ia_sortDirection',
      _sortDirection == AppSortDirection.asc ? 'asc' : 'desc',
    );
    await prefs.setBool('ia_showFavoritesOnly', _showFavoritesOnly);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _isLoading = true);
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        withIcon: true,
      );
      setState(() {
        _allApps = apps;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading installed apps: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.loadFavorites();
    if (mounted) setState(() => _favoritePackages = favs);
  }

  Future<void> _toggleFavorite(String packageName) async {
    final isFav = _favoritePackages.contains(packageName);
    if (isFav) {
      await FavoritesService.removeFavorite(packageName);
      if (mounted) setState(() => _favoritePackages.remove(packageName));
    } else {
      await FavoritesService.addFavorite(packageName);
      if (mounted) setState(() => _favoritePackages.add(packageName));
    }
  }

  Future<void> _massToggleFavorites() async {
    final allFav = _selectedPackages.every(
      (pkg) => _favoritePackages.contains(pkg),
    );
    for (final pkg in _selectedPackages) {
      if (allFav) {
        await FavoritesService.removeFavorite(pkg);
      } else {
        await FavoritesService.addFavorite(pkg);
      }
    }
    if (mounted) {
      setState(() {
        if (allFav) {
          _favoritePackages.removeAll(_selectedPackages);
        } else {
          _favoritePackages.addAll(_selectedPackages);
        }
      });
    }
  }

  Future<void> _uninstallApp(AppInfo app) async {
    try {
      await InstalledApps.uninstallApp(app.packageName);
      InstalledAppsCache.invalidate();
      // Give the system a moment to process the uninstall, then refresh.
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) await _loadInstalledApps();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to uninstall: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUninstallDialog(AppInfo app) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uninstall App'),
        content: Text('Uninstall "${app.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _uninstallApp(app);
            },
            child: const Text(
              'Uninstall',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(AppInfo app) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Package: ${app.packageName}'),
            const SizedBox(height: 8),
            Text('Version: ${app.versionName} (${app.versionCode})'),
            // AppInfo does not expose size natively on all platforms without native code additions
            const SizedBox(height: 8),
            const Text('Size: Unknown'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String packageName) {
    setState(() {
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });
  }

  List<AppInfo> get _filteredAndSortedApps {
    final query = widget.searchQuery.toLowerCase();
    var filtered = _allApps.where((app) {
      final matchesQuery =
          app.name.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
      final matchesFavorites =
          !_showFavoritesOnly || _favoritePackages.contains(app.packageName);
      return matchesQuery && matchesFavorites;
    }).toList();

    filtered.sort((a, b) {
      int comparison;
      switch (_sortOption) {
        case AppSortOption.installTime:
          comparison = a.installedTimestamp.compareTo(b.installedTimestamp);
          break;
        case AppSortOption.name:
          comparison = a.name.compareTo(b.name);
          break;
        case AppSortOption.packageName:
          comparison = a.packageName.compareTo(b.packageName);
          break;
      }
      return _sortDirection == AppSortDirection.asc ? comparison : -comparison;
    });

    return filtered;
  }

  void _showSizeSettings() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Item Size',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.photo_size_select_small),
                      Expanded(
                        child: Slider(
                          value: _baseSize,
                          min: 40.0,
                          max: 120.0,
                          onChanged: (val) {
                            setState(() {
                              _baseSize = val;
                            });
                            setModalState(() {
                              _baseSize = val;
                            });
                            _saveInstalledAppsPrefs();
                          },
                        ),
                      ),
                      const Icon(Icons.photo_size_select_actual),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appsToDisplay = _filteredAndSortedApps;

    // Notify parent about the current count.
    if (widget.onAppCountChanged != null) {
      widget.onAppCountChanged!(appsToDisplay.length);
    }

    return Column(
      children: [
        // The Top Toolbar replacing both AppBar and MainFilterBar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                _isSelectionMode
                    ? '${_selectedPackages.length} selected'
                    : 'Installed Apps',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Filter options next to tab selector
              SegmentedButton<AppViewMode>(
                style: SegmentedButton.styleFrom(
                  elevation: 2,
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.6),
                  selectedBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary,
                  selectedForegroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimary,
                ),
                segments: const [
                  ButtonSegment(
                    value: AppViewMode.grid,
                    icon: Tooltip(
                      message: 'Grid View',
                      child: Icon(Icons.grid_view),
                    ),
                  ),
                  ButtonSegment(
                    value: AppViewMode.list,
                    icon: Tooltip(
                      message: 'List View',
                      child: Icon(Icons.list),
                    ),
                  ),
                  ButtonSegment(
                    value: AppViewMode.iconOnly,
                    icon: Tooltip(
                      message: 'Icon-Only View',
                      child: Icon(Icons.apps),
                    ),
                  ),
                  ButtonSegment(
                    value: AppViewMode.detailList,
                    icon: Tooltip(
                      message: 'Detailed List',
                      child: Icon(Icons.view_agenda),
                    ),
                  ),
                ],
                selected: <AppViewMode>{_viewMode},
                showSelectedIcon: false,
                onSelectionChanged: (Set<AppViewMode> newSelection) {
                  setState(() => _viewMode = newSelection.first);
                  _saveInstalledAppsPrefs();
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<AppSortOption>(
                value: _sortOption,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: AppSortOption.installTime,
                    child: Text('Install Time'),
                  ),
                  DropdownMenuItem(
                    value: AppSortOption.name,
                    child: Text('Name'),
                  ),
                  DropdownMenuItem(
                    value: AppSortOption.packageName,
                    child: Text('Package Name'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _sortOption = val);
                    _saveInstalledAppsPrefs();
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  _sortDirection == AppSortDirection.asc
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _sortDirection = _sortDirection == AppSortDirection.asc
                        ? AppSortDirection.desc
                        : AppSortDirection.asc;
                  });
                  _saveInstalledAppsPrefs();
                },
              ),
              const SizedBox(width: 16),

              if (!_isSelectionMode)
                IconButton(
                  icon: Icon(
                    _showFavoritesOnly ? Icons.star : Icons.star_border,
                    color: _showFavoritesOnly ? Colors.amber : null,
                  ),
                  onPressed: () {
                    setState(() => _showFavoritesOnly = !_showFavoritesOnly);
                    _saveInstalledAppsPrefs();
                  },
                  tooltip: _showFavoritesOnly
                      ? 'Show All Apps'
                      : 'Show Favorites Only',
                ),
              if (!_isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: () => setState(() => _isSelectionMode = true),
                  tooltip: 'Select Apps',
                ),
              if (_isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(() {
                    if (_selectedPackages.length == appsToDisplay.length) {
                      _selectedPackages.clear();
                    } else {
                      _selectedPackages.addAll(
                        appsToDisplay.map((e) => e.packageName),
                      );
                    }
                  }),
                  tooltip: 'Select All',
                ),
                IconButton(
                  icon: Icon(
                    _selectedPackages.isNotEmpty &&
                            _selectedPackages.every(
                              (pkg) => _favoritePackages.contains(pkg),
                            )
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color:
                        _selectedPackages.isNotEmpty &&
                            _selectedPackages.every(
                              (pkg) => _favoritePackages.contains(pkg),
                            )
                        ? Colors.amber
                        : null,
                  ),
                  onPressed: _selectedPackages.isEmpty
                      ? null
                      : _massToggleFavorites,
                  tooltip:
                      _selectedPackages.isNotEmpty &&
                          _selectedPackages.every(
                            (pkg) => _favoritePackages.contains(pkg),
                          )
                      ? 'Remove from Favorites'
                      : 'Add to Favorites',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () {
                    for (var pkg in _selectedPackages) {
                      InstalledApps.uninstallApp(pkg);
                    }
                    setState(() {
                      _isSelectionMode = false;
                      _selectedPackages.clear();
                    });
                  },
                  tooltip: 'Uninstall Selected',
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _isSelectionMode = false;
                    _selectedPackages.clear();
                  }),
                  icon: const Icon(Icons.close, size: 20),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
              if (!_isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: _showSizeSettings,
                  tooltip: 'View Options',
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _isSelectionMode = false;
                  _selectedPackages.clear();
                  _loadInstalledApps();
                },
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 16),
              SegmentedButton<bool>(
                style: SegmentedButton.styleFrom(
                  elevation: 2,
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.6),
                  selectedBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary,
                  selectedForegroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimary,
                ),
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Tooltip(
                      message: 'Store Apps',
                      child: Icon(Icons.storefront),
                    ),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Tooltip(
                      message: 'Installed Apps',
                      child: Icon(Icons.install_mobile),
                    ),
                  ),
                ],
                selected: const {true},
                onSelectionChanged: (Set<bool> sel) {
                  if (widget.onToggleInstalledApps != null) {
                    widget.onToggleInstalledApps!(sel.first);
                  }
                },
              ),
            ],
          ),
        ),

        // App List/Grid
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : appsToDisplay.isEmpty
              ? const Center(child: Text('No user-installed apps found.'))
              : _viewMode == AppViewMode.list
              ? _buildListView(appsToDisplay)
              : _viewMode == AppViewMode.iconOnly
              ? _buildIconOnlyView(appsToDisplay)
              : _viewMode == AppViewMode.detailList
              ? _buildDetailsListView(appsToDisplay)
              : _buildGridView(appsToDisplay),
        ),
      ],
    );
  }

  Widget _buildIconOnlyView(List<AppInfo> apps) {
    final iconSize = _baseSize.clamp(32.0, 80.0);
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: iconSize + 16,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.0,
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = _selectedPackages.contains(app.packageName);
        final isNew = _isNewApp(app);
        return Tooltip(
          message: app.name,
          child: GestureDetector(
            onTap: _isSelectionMode
                ? () => _toggleSelection(app.packageName)
                : () => InstalledApps.startApp(app.packageName),
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedPackages.add(app.packageName);
                });
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: app.icon != null
                        ? Image.memory(app.icon!, fit: BoxFit.contain)
                        : const Icon(Icons.android),
                  ),
                  if (isNew && !_isSelectionMode)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (!_isSelectionMode)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _toggleFavorite(app.packageName),
                        child: Icon(
                          _favoritePackages.contains(app.packageName)
                              ? Icons.star
                              : Icons.star_border,
                          color: _favoritePackages.contains(app.packageName)
                              ? Colors.amber
                              : Colors.white70,
                          size: 14,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  if (_isSelectionMode)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (val) => _toggleSelection(app.packageName),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsListView(List<AppInfo> apps) {
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = _selectedPackages.contains(app.packageName);
        final isNew = _isNewApp(app);
        final installDate = app.installedTimestamp != 0
            ? DateTime.fromMillisecondsSinceEpoch(app.installedTimestamp)
            : null;
        final installDateStr = installDate != null
            ? '${installDate.year}-${installDate.month.toString().padLeft(2, '0')}-${installDate.day.toString().padLeft(2, '0')}'
            : 'Unknown';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isSelected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _isSelectionMode
                ? () => _toggleSelection(app.packageName)
                : () => InstalledApps.startApp(app.packageName),
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedPackages.add(app.packageName);
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: _baseSize,
                    height: _baseSize,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: app.icon != null
                              ? Image.memory(app.icon!, fit: BoxFit.contain)
                              : const Icon(Icons.android),
                        ),
                        if (isNew && !_isSelectionMode)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                app.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.packageName,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.label_outline,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'v${app.versionName} (${app.versionCode})',
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              installDateStr,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!_isSelectionMode) ...[
                    GestureDetector(
                      onTap: () => _toggleFavorite(app.packageName),
                      child: Icon(
                        _favoritePackages.contains(app.packageName)
                            ? Icons.star
                            : Icons.star_border,
                        color: _favoritePackages.contains(app.packageName)
                            ? Colors.amber
                            : null,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'launch') {
                          InstalledApps.startApp(app.packageName);
                        }
                        if (value == 'uninstall') _showUninstallDialog(app);
                        if (value == 'details') _showDetailsDialog(app);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'launch',
                          child: Text('Launch'),
                        ),
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('More Details'),
                        ),
                        const PopupMenuItem(
                          value: 'uninstall',
                          child: Text(
                            'Uninstall',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Checkbox(
                      value: isSelected,
                      onChanged: (val) => _toggleSelection(app.packageName),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isNewApp(AppInfo app) {
    if (app.installedTimestamp == 0) return false;
    final installed = DateTime.fromMillisecondsSinceEpoch(
      app.installedTimestamp,
    );
    return DateTime.now().difference(installed) <= _newAppThreshold;
  }

  Widget _buildListView(List<AppInfo> apps) {
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = _selectedPackages.contains(app.packageName);
        final isNew = _isNewApp(app);

        return ListTile(
          onTap: _isSelectionMode
              ? () => _toggleSelection(app.packageName)
              : () => InstalledApps.startApp(app.packageName),
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedPackages.add(app.packageName);
              });
            }
          },
          tileColor: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
          leading: SizedBox(
            width: _baseSize,
            height: _baseSize,
            child: Stack(
              children: [
                Positioned.fill(
                  child: app.icon != null
                      ? Image.memory(app.icon!, fit: BoxFit.contain)
                      : const Icon(Icons.android),
                ),
                if (!_isSelectionMode)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _toggleFavorite(app.packageName),
                      child: Icon(
                        _favoritePackages.contains(app.packageName)
                            ? Icons.star
                            : Icons.star_border,
                        color: _favoritePackages.contains(app.packageName)
                            ? Colors.amber
                            : Colors.white70,
                        size: 16,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          title: Row(
            children: [
              Text(app.name),
              if (isNew) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text('${app.packageName}\nv${app.versionName}'),
          isThreeLine: true,
          trailing: _isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (val) => _toggleSelection(app.packageName),
                )
              : PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'launch') {
                      InstalledApps.startApp(app.packageName);
                    }
                    if (value == 'uninstall') _showUninstallDialog(app);
                    if (value == 'details') _showDetailsDialog(app);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'launch', child: Text('Launch')),
                    const PopupMenuItem(
                      value: 'details',
                      child: Text('More Details'),
                    ),
                    const PopupMenuItem(
                      value: 'uninstall',
                      child: Text(
                        'Uninstall',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildGridView(List<AppInfo> apps) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _baseSize * 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = _selectedPackages.contains(app.packageName);
        final isNew = _isNewApp(app);

        return Card(
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isSelectionMode
                ? () => _toggleSelection(app.packageName)
                : () => InstalledApps.startApp(app.packageName),
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedPackages.add(app.packageName);
                });
              }
            },
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: app.icon != null
                                  ? Image.memory(app.icon!, fit: BoxFit.contain)
                                  : const Icon(Icons.android, size: 40),
                            ),
                            if (!_isSelectionMode)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _toggleFavorite(app.packageName),
                                  child: Icon(
                                    _favoritePackages.contains(app.packageName)
                                        ? Icons.star
                                        : Icons.star_border,
                                    color:
                                        _favoritePackages.contains(
                                          app.packageName,
                                        )
                                        ? Colors.amber
                                        : Colors.white70,
                                    size: 18,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        app.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isNew && !_isSelectionMode)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                if (_isSelectionMode)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (val) => _toggleSelection(app.packageName),
                    ),
                  )
                else
                  Positioned(
                    top: 0,
                    right: 0,
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 8),
                          Shadow(color: Colors.black54, blurRadius: 3),
                        ],
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'launch') {
                          InstalledApps.startApp(app.packageName);
                        }
                        if (value == 'uninstall') _showUninstallDialog(app);
                        if (value == 'details') _showDetailsDialog(app);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'launch',
                          child: Text('Launch'),
                        ),
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('More Details'),
                        ),
                        const PopupMenuItem(
                          value: 'uninstall',
                          child: Text(
                            'Uninstall',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
