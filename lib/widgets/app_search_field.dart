import 'dart:ui';
import 'package:flutter/material.dart';

import '../utils/localization.dart';
import '../utils/spatial_theme.dart';

/// Search bar with autocomplete suggestions drawn from app names, categories,
/// and tags, plus a recent-search history panel.
class AppSearchField extends StatefulWidget {
  final List<dynamic> apps;
  final List<String> searchHistory;
  final SearchController controller;
  final Future<void> Function(String) onSaveHistory;
  final VoidCallback onClearHistory;

  const AppSearchField({
    super.key,
    required this.apps,
    required this.searchHistory,
    required this.controller,
    required this.onSaveHistory,
    required this.onClearHistory,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _clearSearch() {
    widget.controller.clear();
    if (widget.controller.isOpen) {
      widget.controller.closeView('');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      isFullScreen: false,
      searchController: widget.controller,
      viewConstraints: const BoxConstraints(maxHeight: 300),
      viewBackgroundColor: null,
      viewHintText: 'Search apps...',
      viewOnSubmitted: (value) {
        widget.onSaveHistory(value);
        widget.controller.closeView(value);
      },
      builder: (BuildContext context, SearchController ctl) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final accent = Theme.of(context).colorScheme.primary;
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: TextField(
              controller: ctl,
              onTap: () => ctl.openView(),
              onChanged: (_) => ctl.openView(),
              onSubmitted: (value) {
                widget.onSaveHistory(value);
                ctl.closeView(value);
              },
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search apps...',
                hintStyle: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.40),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.45),
                ),
                suffixIcon: _hasText
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.55)
                              : Colors.black.withValues(alpha: 0.45),
                        ),
                        onPressed: _clearSearch,
                        tooltip: 'Clear search',
                      )
                    : null,
                filled: true,
                fillColor: inputGlassColor(isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: kLightCatchBright),
                    width: 1.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: kLightCatchBright),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: accent.withValues(alpha: 0.75),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
            ),
          ),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController ctl) {
        final String query = ctl.text.toLowerCase();
        if (query.isEmpty) return _buildHistoryItems(ctl);
        return _buildSuggestions(query, ctl);
      },
    );
  }

  Iterable<Widget> _buildHistoryItems(SearchController ctl) {
    final colorScheme = Theme.of(context).colorScheme;
    final List<Widget> items = widget.searchHistory.map((String item) {
      return ListTile(
        leading: Icon(Icons.history, color: colorScheme.onSurface),
        title: Text(item, style: TextStyle(color: colorScheme.onSurface)),
        onTap: () {
          ctl.closeView(item);
          widget.onSaveHistory(item);
        },
      );
    }).toList();

    if (items.isNotEmpty) {
      items.add(
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: Text(
            tr('Clear history'),
            style: const TextStyle(color: Colors.red),
          ),
          onTap: () {
            widget.onClearHistory();
            ctl.closeView('');
            Future.delayed(
              const Duration(milliseconds: 50),
              () => ctl.openView(),
            );
          },
        ),
      );
    }
    return items;
  }

  Iterable<Widget> _buildSuggestions(String query, SearchController ctl) {
    final colorScheme = Theme.of(context).colorScheme;
    final Set<String> suggestions = {};

    for (final app in widget.apps) {
      final name = (app['name'] ?? app['title'] ?? '').toString();
      if (name.toLowerCase().contains(query)) {
        suggestions.add(name);
        for (final w in name.split(RegExp(r'\s+'))) {
          if (w.length > 2 && w.toLowerCase().startsWith(query)) {
            suggestions.add(w);
          }
        }
      }

      final categoryStr = (app['categories'] ?? app['category'] ?? '')
          .toString();
      for (final c in categoryStr.split(',')) {
        if (c.trim().toLowerCase().contains(query)) suggestions.add(c.trim());
      }

      final tagsStr = (app['tags'] ?? '').toString();
      for (final t in tagsStr.replaceAll(RegExp(r'[\[\]"]'), '').split(',')) {
        if (t.trim().toLowerCase().contains(query)) suggestions.add(t.trim());
      }
    }

    return suggestions.take(10).map((String suggestion) {
      return ListTile(
        leading: Icon(Icons.search, color: colorScheme.onSurface),
        title: Text(suggestion, style: TextStyle(color: colorScheme.onSurface)),
        onTap: () {
          ctl.closeView(suggestion);
          widget.onSaveHistory(suggestion);
        },
      );
    });
  }
}
