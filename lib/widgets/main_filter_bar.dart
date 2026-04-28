import 'dart:ui';
import 'package:flutter/material.dart';

import '../utils/localization.dart';
import '../utils/spatial_theme.dart';
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

  // App count display
  final int? displayedCount;
  final int? totalCount;

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
    this.displayedCount,
    this.totalCount,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      // Detached HUD — floats with margin from the edge
      padding: const EdgeInsets.symmetric(
        horizontal: kFloatMargin,
        vertical: 2.0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: kBlurBase, sigmaY: kBlurBase),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: glassColor(isDark),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: kLightCatchBright),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.35 : 0.10,
                  ),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // ── Genre sidebar toggle ────────────────────────────────
                  if (!showInstalledApps) ...[
                    _HudPill(
                      label: 'Genres',
                      icon: Icons.label_outline_rounded,
                      isActive: genreSidebarOpen,
                      isDark: isDark,
                      accent: accent,
                      onTap: onGenreToggle,
                    ),
                    if (genreFilter != 'All Genres') ...[
                      const SizedBox(width: 6),
                      _HudPill(
                        icon: Icons.close_rounded,
                        isDark: isDark,
                        accent: Colors.redAccent,
                        onTap: onClearGenre,
                        tooltip: 'Clear genre filter',
                      ),
                    ],
                    const SizedBox(width: 8),
                    const _HudDivider(),
                    const SizedBox(width: 8),
                  ],

                  // ── Favorites toggle ────────────────────────────────────
                  if (!showInstalledApps) ...[
                    _HudPill(
                      icon: favoritesOnly
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      label: tr('Favorites'),
                      isActive: favoritesOnly,
                      isDark: isDark,
                      accent: Colors.amber,
                      onTap: () => onFavoritesOnlyChanged(!favoritesOnly),
                    ),
                    const SizedBox(width: 8),
                    const _HudDivider(),
                    const SizedBox(width: 8),
                  ],

                  const Spacer(),

                  // ── App count ─────────────────────────────────────────
                  if (!showInstalledApps &&
                      displayedCount != null &&
                      totalCount != null)
                    Text(
                      '$displayedCount / $totalCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : Colors.black.withValues(alpha: 0.38),
                      ),
                    ),

                  const Spacer(),

                  // ── View mode toggle ────────────────────────────────────
                  if (!showInstalledApps) ...[
                    _HudIconToggle(
                      value: 'grid',
                      icon: Icons.grid_view_rounded,
                      current: viewMode,
                      isDark: isDark,
                      accent: accent,
                      tooltip: tr('Grid View'),
                      onTap: () => onViewModeChanged('grid'),
                    ),
                    const SizedBox(width: 4),
                    _HudIconToggle(
                      value: 'master_detail',
                      icon: Icons.vertical_split_rounded,
                      current: viewMode,
                      isDark: isDark,
                      accent: accent,
                      tooltip: tr('Master Detail'),
                      onTap: () => onViewModeChanged('master_detail'),
                    ),
                    const SizedBox(width: 8),
                    const _HudDivider(),
                    const SizedBox(width: 8),
                    // ── Sort dropdown ─────────────────────────────────────
                    FilterDropdown(
                      value: sortOption,
                      icon: Icons.sort_rounded,
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
                    const SizedBox(width: 8),
                    const _HudDivider(),
                    const SizedBox(width: 8),
                  ],

                  // ── Store / Installed toggle ────────────────────────────
                  _HudIconToggle(
                    value: false,
                    icon: Icons.storefront_rounded,
                    current: showInstalledApps,
                    isDark: isDark,
                    accent: accent,
                    tooltip: 'Store Apps',
                    onTap: () => onToggleInstalledApps(false),
                  ),
                  const SizedBox(width: 4),
                  _HudIconToggle(
                    value: true,
                    icon: Icons.install_mobile_rounded,
                    current: showInstalledApps,
                    isDark: isDark,
                    accent: accent,
                    tooltip: 'Installed Apps',
                    onTap: () => onToggleInstalledApps(true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Spatial HUD helper widgets ────────────────────────────────────────────────

/// A pill button inside the floating filter HUD.
class _HudPill extends StatefulWidget {
  final String? label;
  final IconData icon;
  final bool isActive;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;
  final String? tooltip;

  const _HudPill({
    required this.icon,
    required this.isDark,
    required this.accent,
    required this.onTap,
    this.label,
    this.isActive = false,
    this.tooltip,
  });

  @override
  State<_HudPill> createState() => _HudPillState();
}

class _HudPillState extends State<_HudPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget pill = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: _pressed ? 0.95 : 1.0),
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutQuint,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutQuint,
          padding: EdgeInsets.symmetric(
            horizontal: widget.label != null ? 10 : 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.accent.withValues(alpha: _pressed ? 0.70 : 0.85)
                : Colors.white.withValues(
                    alpha: widget.isDark ? (0.06) : 0.30,
                  ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.isActive
                  ? widget.accent.withValues(alpha: 0.90)
                  : Colors.white.withValues(alpha: kLightCatchBright),
              width: 1.0,
            ),
            boxShadow: _pressed
                ? []
                : widget.isActive
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.35),
                      blurRadius: kGlowBlur,
                      spreadRadius: kGlowSpread,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isActive
                    ? Colors.white
                    : widget.isDark
                    ? Colors.white.withValues(alpha: 0.75)
                    : Colors.black.withValues(alpha: 0.60),
              ),
              if (widget.label != null) ...[
                const SizedBox(width: 5),
                Text(
                  widget.label!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: widget.isActive
                        ? Colors.white
                        : widget.isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : Colors.black.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: pill);
    }
    return pill;
  }
}

/// An icon-only toggle inside the HUD (active = accent background + glow).
class _HudIconToggle<T> extends StatefulWidget {
  final T value;
  final T current;
  final IconData icon;
  final bool isDark;
  final Color accent;
  final String tooltip;
  final VoidCallback onTap;

  const _HudIconToggle({
    required this.value,
    required this.current,
    required this.icon,
    required this.isDark,
    required this.accent,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HudIconToggle<T>> createState() => _HudIconToggleState<T>();
}

class _HudIconToggleState<T> extends State<_HudIconToggle<T>> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.value == widget.current;

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: _pressed ? 0.92 : 1.0),
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutQuint,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutQuint,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive
                  ? widget.accent.withValues(alpha: _pressed ? 0.70 : 0.85)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: isActive
                  ? Border.all(
                      color: widget.accent.withValues(alpha: 0.90),
                      width: 1.0,
                    )
                  : null,
              boxShadow: isActive && !_pressed
                  ? [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.35),
                        blurRadius: kGlowBlur,
                        spreadRadius: kGlowSpread,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              widget.icon,
              size: 15,
              color: isActive
                  ? Colors.white
                  : widget.isDark
                  ? Colors.white.withValues(alpha: 0.65)
                  : Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _HudDivider extends StatelessWidget {
  const _HudDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 20,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.30),
      ),
    );
  }
}

/// Spatial pill-strip for filtering by app type (All / Game / App …).
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    final types = <String>['all', ...availableTypes];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: types.map((type) {
        final isActive = type == selected;
        IconData iconData;
        String label;
        if (type == 'all') {
          iconData = Icons.apps_rounded;
          label = tr('All');
        } else if (type == 'game') {
          iconData = Icons.sports_esports_rounded;
          label = 'Games';
        } else if (type == 'app') {
          iconData = Icons.developer_board_rounded;
          label = 'Apps';
        } else {
          iconData = Icons.extension_rounded;
          label = type[0].toUpperCase() + type.substring(1);
        }

        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _HudPill(
            icon: iconData,
            label: label,
            isDark: isDark,
            accent: accent,
            isActive: isActive,
            onTap: () => onChanged(type),
          ),
        );
      }).toList(),
    );
  }
}
