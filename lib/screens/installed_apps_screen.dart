import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_enrichment_service.dart';
import '../services/favorites_service.dart';
import '../utils/installed_apps_cache.dart';
import '../utils/spatial_theme.dart';
import '../widgets/adjustable_split_view.dart';
import '../widgets/installed_app_detail_panel.dart';

enum AppViewMode { list, grid, iconOnly, detailList, masterDetail }

enum AppSortOption { installTime, name, packageName }

enum AppSortDirection { asc, desc }

const Duration _newAppThreshold = Duration(days: 7);

class InstalledAppsScreen extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<bool>? onToggleInstalledApps;
  final ValueChanged<int>? onAppCountChanged;

  /// Optional Supabase catalog apps used to look up descriptions by package name.
  final List<dynamic> dbApps;

  const InstalledAppsScreen({
    super.key,
    this.searchQuery = '',
    this.onToggleInstalledApps,
    this.onAppCountChanged,
    this.dbApps = const [],
  });

  @override
  State<InstalledAppsScreen> createState() => _InstalledAppsScreenState();
}

class _InstalledAppsScreenState extends State<InstalledAppsScreen> {
  List<AppInfo> _allApps = [];
  bool _isLoading = true;

  // Enrichment: sizes loaded asynchronously, keyed by packageName
  final Map<String, String> _appSizeLabels = {};
  final _enrichment = AppEnrichmentService.instance;

  // Master-detail selection
  AppInfo? _selectedApp;

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
      _loadAllSizes(apps);
    } catch (e) {
      debugPrint('Error loading installed apps: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllSizes(List<AppInfo> apps) async {
    for (final app in apps) {
      if (_appSizeLabels.containsKey(app.packageName)) continue;
      final label = await _enrichment.getAppSizeLabel(app);
      if (mounted) {
        setState(() => _appSizeLabels[app.packageName] = label);
      }
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
    final description = _enrichment.getDescription(
      app.packageName,
      widget.dbApps,
    );
    final sizeLabel = _appSizeLabels[app.packageName] ?? 'Loading…';
    final installDate = app.installedTimestamp != 0
        ? DateTime.fromMillisecondsSinceEpoch(app.installedTimestamp)
        : null;
    final installDateStr = installDate != null
        ? '${installDate.year}-'
              '${installDate.month.toString().padLeft(2, '0')}-'
              '${installDate.day.toString().padLeft(2, '0')}'
        : 'Unknown';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            if (app.icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Image.memory(app.icon!, fit: BoxFit.contain),
                ),
              ),
            Expanded(child: Text(app.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(
                  Icons.inventory_2_outlined,
                  'Package',
                  app.packageName,
                ),
                const Divider(height: 16),
                _detailRow(
                  Icons.label_outline,
                  'Version',
                  '${app.versionName} (build ${app.versionCode})',
                ),
                const Divider(height: 16),
                _detailRow(Icons.storage_outlined, 'Size', sizeLabel),
                const Divider(height: 16),
                _detailRow(
                  Icons.calendar_today_outlined,
                  'Installed',
                  installDateStr,
                ),
                if (description.isNotEmpty) ...[
                  const Divider(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
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

  static Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
          padding: const EdgeInsets.symmetric(
            horizontal: kFloatMargin,
            vertical: 2.0,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: kBlurBase,
                sigmaY: kBlurBase,
              ),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: glassColor(
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: kLightCatchBright),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.35
                            : 0.10,
                      ),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
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
                  ButtonSegment(
                    value: AppViewMode.masterDetail,
                    icon: Tooltip(
                      message: 'Master-Detail',
                      child: Icon(Icons.vertical_split_outlined),
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
            ),
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
              : _viewMode == AppViewMode.masterDetail
              ? _buildMasterDetailView(appsToDisplay)
              : _buildGridView(appsToDisplay),
        ),
      ],
    );
  }

  Widget _buildMasterDetailView(List<AppInfo> apps) {
    // Keep _selectedApp valid when the list changes.
    final AppInfo? effectiveSelected =
        _selectedApp != null &&
            apps.any((a) => a.packageName == _selectedApp!.packageName)
        ? apps.firstWhere((a) => a.packageName == _selectedApp!.packageName)
        : null;

    final masterList = ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = app.packageName == effectiveSelected?.packageName;
        final isNew = _isNewApp(app);

        return Material(
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.55)
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _selectedApp = app);
            },
            child: Container(
              decoration: isSelected
                  ? BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        ),
                      ),
                    )
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: app.icon != null
                              ? Image.memory(app.icon!, fit: BoxFit.contain)
                              : const Icon(Icons.android),
                        ),
                        if (isNew)
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${app.versionName}  \u2022  ${_appSizeLabels[app.packageName] ?? '\u2026'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_favoritePackages.contains(app.packageName))
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                ],
              ),
            ),
          ),
        );
      },
    );

    final detailPanel = InstalledAppDetailPanel(
      app: effectiveSelected,
      dbApps: widget.dbApps,
      favoritePackages: _favoritePackages,
      onToggleFavorite: _toggleFavorite,
      onUninstall: effectiveSelected != null
          ? () => _showUninstallDialog(effectiveSelected)
          : null,
    );

    return AdjustableSplitView(
      initialLeftWidthPercentage: 0.38,
      left: masterList,
      right: detailPanel,
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
        final sizeLabel = _appSizeLabels[app.packageName];
        final tooltipMsg = sizeLabel != null
            ? '${app.name}\n${app.packageName}\n$sizeLabel'
            : '${app.name}\n${app.packageName}';
        return Tooltip(
          message: tooltipMsg,
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
                            const SizedBox(width: 12),
                            Icon(
                              Icons.storage_outlined,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _appSizeLabels[app.packageName] ?? '…',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        Builder(
                          builder: (_) {
                            final desc = _enrichment.getDescription(
                              app.packageName,
                              widget.dbApps,
                            );
                            if (desc.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                desc,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.75),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
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
          subtitle: Text(
            '${app.packageName}\n'
            'v${app.versionName}  \u2022  ${_appSizeLabels[app.packageName] ?? '\u2026'}',
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
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
        final isFav = _favoritePackages.contains(app.packageName);

        return GestureDetector(
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadiusSmall),
              border: Border.all(
                color: isSelected
                    ? accent
                    : Colors.white.withValues(alpha: kLightCatchBright),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                  blurRadius: 18,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kRadiusSmall),
              child: Stack(
                children: [
                  // App icon fill
                  Positioned.fill(
                    child: app.icon != null
                        ? Image.memory(app.icon!, fit: BoxFit.cover)
                        : Container(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            child: const Center(
                              child: Icon(Icons.android, size: 40),
                            ),
                          ),
                  ),

                  // Bottom frosted glass info bar
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
                          color: glassColor(isDark),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                app.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              if (_appSizeLabels[app.packageName] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _appSizeLabels[app.packageName]!,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // NEW badge
                  if (isNew && !_isSelectionMode)
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // Favorite star (frosted circle)
                  if (!_isSelectionMode)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _toggleFavorite(app.packageName),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isFav
                                    ? Colors.amber.withValues(alpha: 0.85)
                                    : Colors.black.withValues(alpha: 0.30),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isFav
                                      ? Colors.amber.withValues(alpha: 0.80)
                                      : Colors.white.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                isFav
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 12,
                                color: isFav ? Colors.black87 : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Selection checkbox
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
                    // 3-dot menu
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
          ),
        );
      },
    );
  }
}
