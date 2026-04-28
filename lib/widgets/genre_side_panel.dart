import 'dart:ui';
import 'package:flutter/material.dart';

import '../utils/spatial_theme.dart';

/// Strips leading `#` characters and returns the display label for a genre.
String _displayGenre(String genre) {
  final stripped = genre.replaceFirst(RegExp(r'^#+'), '');
  return stripped.isEmpty ? genre : stripped;
}

/// Returns a 1–2 char abbreviation for the collapsed icon strip.
String _genreAbbr(String genre) {
  if (genre == 'All Genres') return '★';
  final display = _displayGenre(genre);
  return display.isNotEmpty ? display.substring(0, 1).toUpperCase() : '?';
}

/// Spatial Dock — a glass panel listing genres.
/// Open: 220px frosted-glass panel. Collapsed: 52px icon strip bubble.
class GenreSidePanel extends StatefulWidget {
  final List<String> genres;
  final String selected;
  final int Function(String) getGenreCount;
  final ValueChanged<String> onChanged;
  final bool isOpen;
  final VoidCallback onToggle;

  const GenreSidePanel({
    super.key,
    required this.genres,
    required this.selected,
    required this.getGenreCount,
    required this.onChanged,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  State<GenreSidePanel> createState() => _GenreSidePanelState();
}

class _GenreSidePanelState extends State<GenreSidePanel> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.genres;
    _searchController.addListener(_onSearch);
  }

  @override
  void didUpdateWidget(GenreSidePanel old) {
    super.didUpdateWidget(old);
    if (old.genres != widget.genres) _onSearch();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.genres
          : widget.genres
              .where((g) => _displayGenre(g).toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final isOpen = widget.isOpen;

    return Padding(
      // Floating margin — never pinned to the edge
      padding: const EdgeInsets.symmetric(vertical: kFloatMargin),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuint,
        width: isOpen ? 220 : 52,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: kBlurBase, sigmaY: kBlurBase),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutQuint,
              decoration: BoxDecoration(
                color: glassColor(isDark),
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: kLightCatchBright),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(4, 0),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOpen) ...[
                    // ── Toggle collapse button ──────────────────────────
                    _DockToggleButton(
                      isOpen: true,
                      isDark: isDark,
                      accent: accent,
                      onTap: widget.onToggle,
                    ),

                    // ── Search field (carved glass) ─────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search genres…',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : Colors.black.withValues(alpha: 0.40),
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 15,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : Colors.black.withValues(alpha: 0.40),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              filled: true,
                              fillColor: inputGlassColor(isDark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide(
                                  color: Colors.white
                                      .withValues(alpha: kLightCatchBright),
                                  width: 1.0,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide(
                                  color: Colors.white
                                      .withValues(alpha: kLightCatchBright),
                                  width: 1.0,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide(
                                  color: accent.withValues(alpha: 0.70),
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Genre list ─────────────────────────────────────
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 8,
                          top: 4,
                          bottom: 16,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final genre = _filtered[i];
                          final isSelected = genre == widget.selected;
                          final count = widget.getGenreCount(genre);

                          return _DockGenreItem(
                            label: _displayGenre(genre),
                            count: count,
                            isSelected: isSelected,
                            isAllGenres: genre == 'All Genres',
                            isDark: isDark,
                            accent: accent,
                            onTap: () => widget.onChanged(genre),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    // ── Collapsed icon strip ────────────────────────────
                    _DockToggleButton(
                      isOpen: false,
                      isDark: isDark,
                      accent: accent,
                      onTap: widget.onToggle,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: widget.genres.map((genre) {
                            final isSelected = genre == widget.selected;
                            final label = _genreAbbr(genre);

                            return Tooltip(
                              message: _displayGenre(genre),
                              preferBelow: false,
                              waitDuration: const Duration(milliseconds: 200),
                              child: GestureDetector(
                                onTap: () => widget.onChanged(genre),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  curve: Curves.easeOutQuint,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accent.withValues(alpha: 0.85)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                    border: isSelected
                                        ? Border.all(
                                            color: accent.withValues(
                                              alpha: 0.90,
                                            ),
                                            width: 1,
                                          )
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: accent.withValues(
                                                alpha: 0.45,
                                              ),
                                              blurRadius: kGlowBlur,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? Colors.white
                                          : isDark
                                          ? Colors.white.withValues(alpha: 0.55)
                                          : Colors.black.withValues(alpha: 0.50),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dock collapse/expand toggle button ────────────────────────────────────────

class _DockToggleButton extends StatelessWidget {
  final bool isOpen;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;

  const _DockToggleButton({
    required this.isOpen,
    required this.isDark,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isOpen ? 10 : 6, 10, isOpen ? 4 : 6, 6),
      child: Row(
        mainAxisAlignment:
            isOpen ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
        children: [
          if (isOpen)
            Text(
              'Genres',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.75)
                    : Colors.black.withValues(alpha: 0.65),
                letterSpacing: 0.6,
              ),
            ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: kLightCatchBright),
                  width: 1,
                ),
              ),
              child: Icon(
                isOpen
                    ? Icons.keyboard_arrow_left_rounded
                    : Icons.keyboard_arrow_right_rounded,
                size: 16,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.70)
                    : Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual genre dock item ─────────────────────────────────────────────────

class _DockGenreItem extends StatefulWidget {
  final String label;
  final int count;
  final bool isSelected;
  final bool isAllGenres;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;

  const _DockGenreItem({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.isAllGenres,
    required this.isDark,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_DockGenreItem> createState() => _DockGenreItemState();
}

class _DockGenreItemState extends State<_DockGenreItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutQuint,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.accent.withValues(alpha: 0.82)
                  : _hovered
                  ? Colors.white.withValues(alpha: widget.isDark ? 0.08 : 0.30)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: widget.isSelected
                  ? Border.all(
                      color: widget.accent.withValues(alpha: 0.90),
                      width: 1.0,
                    )
                  : _hovered
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.0,
                    )
                  : null,
              boxShadow: widget.isSelected
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
              children: [
                if (widget.isAllGenres) ...[
                  Icon(
                    Icons.apps_rounded,
                    size: 12,
                    color: widget.isSelected
                        ? Colors.white
                        : widget.isDark
                        ? Colors.white.withValues(alpha: 0.55)
                        : Colors.black.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: widget.isSelected
                          ? Colors.white
                          : widget.isDark
                          ? Colors.white.withValues(alpha: 0.80)
                          : Colors.black.withValues(alpha: 0.72),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.white.withValues(
                            alpha: widget.isDark ? 0.08 : 0.40,
                          ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: widget.isSelected
                          ? Colors.white
                          : widget.isDark
                          ? Colors.white.withValues(alpha: 0.55)
                          : Colors.black.withValues(alpha: 0.50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

