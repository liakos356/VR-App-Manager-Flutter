import 'package:flutter/material.dart';

import '../utils/localization.dart';
import '../widgets/filter_dropdown.dart';

/// AppBar bottom bar with category filter, ovrport toggle, view-mode toggle,
/// and sort dropdown.
///
/// Implements [PreferredSizeWidget] so it can be passed directly to
/// [AppBar.bottom].
class MainFilterBar extends StatelessWidget implements PreferredSizeWidget {
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

  const MainFilterBar({
    super.key,
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
