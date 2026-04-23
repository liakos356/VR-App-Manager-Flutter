import 'package:flutter/material.dart';

import '../utils/localization.dart';
import '../widgets/filter_dropdown.dart';

/// AppBar bottom bar with view-mode toggle and sort dropdown.
///
/// Implements [PreferredSizeWidget] so it can be passed directly to
/// [AppBar.bottom].
class MainFilterBar extends StatelessWidget implements PreferredSizeWidget {
  final String viewMode;
  final String sortOption;
  final bool genreSidebarOpen;
  final String genreFilter;
  final VoidCallback onGenreToggle;
  final VoidCallback onClearGenre;
  final ValueChanged<String> onViewModeChanged;
  final ValueChanged<String?> onSortChanged;

  // New properties for Installed Apps toggle
  final bool showInstalledApps;
  final ValueChanged<bool> onToggleInstalledApps;

  // Favorites-only filter
  final bool favoritesOnly;
  final ValueChanged<bool> onFavoritesOnlyChanged;

  const MainFilterBar({
    super.key,
    required this.viewMode,
    required this.sortOption,
    required this.genreSidebarOpen,
    required this.genreFilter,
    required this.onGenreToggle,
    required this.onClearGenre,
    required this.onViewModeChanged,
    required this.onSortChanged,
    this.showInstalledApps = false,
    required this.onToggleInstalledApps,
    this.favoritesOnly = false,
    required this.onFavoritesOnlyChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // ── Genre sidebar toggle ──────────────────────────────────────
          if (!showInstalledApps)
            Tooltip(
              message: genreSidebarOpen
                  ? 'Hide genre panel'
                  : 'Show genre panel',
              child: Material(
                elevation: genreSidebarOpen ? 3 : 2,
                borderRadius: BorderRadius.circular(20),
                color: genreSidebarOpen
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).cardColor,
                child: InkWell(
                  onTap: onGenreToggle,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.label_outline_rounded,
                          size: 16,
                          color: genreSidebarOpen
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Genres',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: genreSidebarOpen
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: genreSidebarOpen
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          genreSidebarOpen
                              ? Icons.keyboard_arrow_left_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          size: 14,
                          color: genreSidebarOpen
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!showInstalledApps && genreFilter != 'All Genres') ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Clear genre filter',
              child: Material(
                elevation: 0,
                borderRadius: BorderRadius.circular(20),
                color: Colors.transparent,
                child: InkWell(
                  onTap: onClearGenre,
                  borderRadius: BorderRadius.circular(20),
                  hoverColor: Colors.red.withValues(alpha: 0.12),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),

          // ── Favorites-only toggle ─────────────────────────────────────
          if (!showInstalledApps) ...[
            Tooltip(
              message: favoritesOnly ? 'Show all apps' : 'Show favorites only',
              child: Material(
                elevation: favoritesOnly ? 3 : 2,
                borderRadius: BorderRadius.circular(20),
                color: favoritesOnly
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).cardColor,
                child: InkWell(
                  onTap: () => onFavoritesOnlyChanged(!favoritesOnly),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          favoritesOnly
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 16,
                          color: favoritesOnly
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr('Favorites'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: favoritesOnly
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: favoritesOnly
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          if (!showInstalledApps) ...[
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                elevation: 2,
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black.withValues(alpha: 0.6),
                selectedBackgroundColor: Theme.of(context).colorScheme.primary,
                selectedForegroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimary,
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
                DropdownMenuItem(
                  value: 'Newest First',
                  child: Text(tr('Newest First')),
                ),
                DropdownMenuItem(
                  value: 'Oldest First',
                  child: Text(tr('Oldest First')),
                ),
              ],
              onChanged: onSortChanged,
            ),
            const SizedBox(width: 16),
          ],

          SegmentedButton<bool>(
            style: SegmentedButton.styleFrom(
              elevation: 2,
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.black.withValues(alpha: 0.6),
              selectedBackgroundColor: Theme.of(context).colorScheme.primary,
              selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
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
            selected: {showInstalledApps},
            onSelectionChanged: (Set<bool> sel) =>
                onToggleInstalledApps(sel.first),
          ),
        ],
      ),
    );
  }
}

/// Segmented button that lets the user filter by app type (All / Game / App …).
class AppTypeSegmentedButton extends StatelessWidget {
  final List<String> availableTypes;
  final String selected;
  final ValueChanged<String> onChanged;

  const AppTypeSegmentedButton({
    super.key,
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
