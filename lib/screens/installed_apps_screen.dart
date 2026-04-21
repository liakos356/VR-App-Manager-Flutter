import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import '../utils/installed_apps_cache.dart';

enum AppViewMode { list, grid }

enum AppSortOption { name, packageName }

enum AppSortDirection { asc, desc }

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

  // Search & Filter state
  AppSortOption _sortOption = AppSortOption.name;
  AppSortDirection _sortDirection = AppSortDirection.asc;

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
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
      return app.name.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      int comparison;
      switch (_sortOption) {
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
                ],
                selected: <AppViewMode>{_viewMode},
                showSelectedIcon: false,
                onSelectionChanged: (Set<AppViewMode> newSelection) {
                  setState(() => _viewMode = newSelection.first);
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<AppSortOption>(
                value: _sortOption,
                underline: const SizedBox(),
                items: const [
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
                  if (val != null) setState(() => _sortOption = val);
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
                },
              ),
              const SizedBox(width: 16),

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
              : _buildGridView(appsToDisplay),
        ),
      ],
    );
  }

  Widget _buildListView(List<AppInfo> apps) {
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = _selectedPackages.contains(app.packageName);

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
            child: app.icon != null
                ? Image.memory(app.icon!, fit: BoxFit.contain)
                : const Icon(Icons.android),
          ),
          title: Text(app.name),
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
                        child: app.icon != null
                            ? Image.memory(app.icon!, fit: BoxFit.contain)
                            : const Icon(Icons.android, size: 40),
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
                      icon: const Icon(Icons.more_vert, size: 20),
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
