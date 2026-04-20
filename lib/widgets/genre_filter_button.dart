import 'package:flutter/material.dart';

/// A styled button that shows the currently selected genre and opens a
/// searchable picker dialog when tapped.
class GenreFilterButton extends StatelessWidget {
  final String value;
  final List<String> genres;
  final int Function(String) getGenreCount;
  final ValueChanged<String?> onChanged;

  const GenreFilterButton({
    super.key,
    required this.value,
    required this.genres,
    required this.getGenreCount,
    required this.onChanged,
  });

  void _openPicker(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (_) => _GenrePickerDialog(
        genres: genres,
        getGenreCount: getGenreCount,
        selected: value,
      ),
    ).then((picked) {
      if (picked != null) onChanged(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).cardColor,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.label_outline, size: 20),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenrePickerDialog extends StatefulWidget {
  final List<String> genres;
  final int Function(String) getGenreCount;
  final String selected;

  const _GenrePickerDialog({
    required this.genres,
    required this.getGenreCount,
    required this.selected,
  });

  @override
  State<_GenrePickerDialog> createState() => _GenrePickerDialogState();
}

class _GenrePickerDialogState extends State<_GenrePickerDialog> {
  late List<String> _filtered;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.genres;
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.genres
          : widget.genres
              .where((g) => g.toLowerCase().contains(q))
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 320,
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Genres',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search genres…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const Divider(height: 8),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final genre = _filtered[index];
                  final isAllGenres = genre == 'All Genres';
                  final count = widget.getGenreCount(genre);
                  final isSelected = genre == widget.selected;

                  return ListTile(
                    dense: true,
                    title: Text(
                      isAllGenres ? 'All Genres ($count)' : '$genre ($count)',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Theme.of(context).primaryColor,
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            size: 18,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(genre),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
