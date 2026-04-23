import 'package:flutter/material.dart';

import '../utils/localization.dart';

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
    widget.controller.closeView('');
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      isFullScreen: false,
      searchController: widget.controller,
      viewConstraints: const BoxConstraints(maxHeight: 300),
      viewOnSubmitted: (value) {
        widget.onSaveHistory(value);
        widget.controller.closeView(value);
      },
      builder: (BuildContext context, SearchController ctl) {
        return Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(20),
          child: TextField(
            controller: ctl,
            onTap: () => ctl.openView(),
            onChanged: (_) => ctl.openView(),
            onSubmitted: (value) {
              widget.onSaveHistory(value);
              ctl.closeView(value);
            },
            decoration: InputDecoration(
              hintText: 'Search apps...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _hasText
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _clearSearch,
                      tooltip: 'Clear search',
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
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
    final List<Widget> items = widget.searchHistory.map((String item) {
      return ListTile(
        leading: const Icon(Icons.history),
        title: Text(item),
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
        leading: const Icon(Icons.search),
        title: Text(suggestion),
        onTap: () {
          ctl.closeView(suggestion);
          widget.onSaveHistory(suggestion);
        },
      );
    });
  }
}
