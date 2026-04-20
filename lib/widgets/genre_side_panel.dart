import 'package:flutter/material.dart';

/// Strips leading `#` characters and returns the display label for a genre.
/// e.g. "#Action" → "Action", "All Genres" → "All Genres"
String _displayGenre(String genre) {
  final stripped = genre.replaceFirst(RegExp(r'^#+'), '');
  return stripped.isEmpty ? genre : stripped;
}

/// Returns a 1–2 char abbreviation for use in the collapsed icon strip.
String _genreAbbr(String genre) {
  if (genre == 'All Genres') return '★';
  final display = _displayGenre(genre);
  return display.isNotEmpty ? display.substring(0, 1).toUpperCase() : '?';
}

/// A collapsible side panel that lists genres with a search filter.
/// When [isOpen] is true, it shows a 220px panel with a search field and
/// the full genre list. When collapsed it shrinks to a 52px icon strip.
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
    if (old.genres != widget.genres) {
      _onSearch();
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOpen = widget.isOpen;

    // ── Palette ────────────────────────────────────────────────────────────
    final panelBg = isDark
        ? const Color(0xFF252526)   // matches AppBar dark bg
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.09);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    final selectedBg = colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.10);
    final mutedText = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.38);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: isOpen ? 220 : 52,
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(
          right: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 10,
            offset: const Offset(3, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          if (isOpen) ...[
            // ── Search field ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search genres…',
                  hintStyle: TextStyle(fontSize: 12, color: mutedText),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: mutedText,
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: borderColor, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),

            // ── Genre list ────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final genre = _filtered[i];
                  final isAllGenres = genre == 'All Genres';
                  final isSelected = genre == widget.selected;
                  final count = widget.getGenreCount(genre);
                  final displayName = _displayGenre(genre);

                  return _GenreItem(
                    label: displayName,
                    count: count,
                    isSelected: isSelected,
                    isAllGenres: isAllGenres,
                    isDark: isDark,
                    selectedBg: selectedBg,
                    hoverBg: hoverBg,
                    primary: colorScheme.primary,
                    mutedText: mutedText,
                    onTap: () => widget.onChanged(genre),
                  );
                },
              ),
            ),
          ] else ...[
            // ── Collapsed icon strip ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Column(
                  children: widget.genres.map((genre) {
                    final isSelected = genre == widget.selected;
                    final label = _genreAbbr(genre);
                    final isAllGenres = genre == 'All Genres';

                    return Tooltip(
                      message: _displayGenre(genre),
                      preferBelow: false,
                      waitDuration: const Duration(milliseconds: 300),
                      child: InkWell(
                        onTap: () => widget.onChanged(genre),
                        hoverColor: hoverBg,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? selectedBg : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: isAllGenres ? 14 : 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? colorScheme.primary
                                  : isDark
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : Colors.black.withValues(alpha: 0.5),
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
    );
  }
}

// ── Individual genre row ───────────────────────────────────────────────────────

class _GenreItem extends StatefulWidget {
  final String label;
  final int count;
  final bool isSelected;
  final bool isAllGenres;
  final bool isDark;
  final Color selectedBg;
  final Color hoverBg;
  final Color primary;
  final Color mutedText;
  final VoidCallback onTap;

  const _GenreItem({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.isAllGenres,
    required this.isDark,
    required this.selectedBg,
    required this.hoverBg,
    required this.primary,
    required this.mutedText,
    required this.onTap,
  });

  @override
  State<_GenreItem> createState() => _GenreItemState();
}

class _GenreItemState extends State<_GenreItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isSelected
        ? widget.primary
        : widget.isDark
        ? Colors.white.withValues(alpha: 0.82)
        : Colors.black.withValues(alpha: 0.75);
    final badgeBg = widget.isSelected
        ? widget.primary.withValues(alpha: 0.18)
        : widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);
    final badgeText = widget.isSelected
        ? widget.primary
        : widget.mutedText;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.selectedBg
                : _hovered
                ? widget.hoverBg
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.isSelected
                    ? widget.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              // Icon for "All Genres"
              if (widget.isAllGenres) ...[
                Icon(
                  Icons.apps_rounded,
                  size: 13,
                  color: widget.isSelected ? widget.primary : widget.mutedText,
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeText,
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

