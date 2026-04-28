import 'package:flutter/material.dart';

/// Returns the "effective first letter" for alphabetic indexing.
///
/// Rules:
/// - Strips a leading "The " prefix (case-insensitive).
/// - Returns the first uppercase letter.
/// - Returns '0-9' if the first character is a digit.
/// - Returns '#' for any other leading character (symbols etc.).
String appEffectiveLetter(String name) {
  var n = name.trim();
  if (n.toLowerCase().startsWith('the ') && n.length > 4) {
    n = n.substring(4).trimLeft();
  }
  if (n.isEmpty) return '#';
  final first = n[0].toUpperCase();
  if (RegExp(r'[0-9]').hasMatch(first)) return '0-9';
  if (RegExp(r'[A-Z]').hasMatch(first)) return first;
  return '#';
}

/// Computes the sorted list of unique index entries from [apps].
/// Only entries that have at least one app are included.
/// Order: '0-9' first, then letters A–Z, then '#'.
List<String> computeAlphaIndex(List<dynamic> apps) {
  final letters = <String>{};
  for (final app in apps) {
    final name = (app['name'] ?? app['title'] ?? '').toString();
    letters.add(appEffectiveLetter(name));
  }
  final sorted = letters.toList()
    ..sort((a, b) {
      if (a == '0-9' && b != '0-9') return -1;
      if (a != '0-9' && b == '0-9') return 1;
      if (a == '#' && b != '#') return 1;
      if (a != '#' && b == '#') return -1;
      return a.compareTo(b);
    });
  return sorted;
}

/// Returns the index of the first app in [apps] whose effective letter equals
/// [letter]. Returns -1 if none found.
int findFirstIndexForLetter(List<dynamic> apps, String letter) {
  for (int i = 0; i < apps.length; i++) {
    final name = (apps[i]['name'] ?? apps[i]['title'] ?? '').toString();
    if (appEffectiveLetter(name) == letter) return i;
  }
  return -1;
}

/// A persistent narrow column that shows an alphabetic index for fast-scrolling.
///
/// Shows only letters that are present in [apps] (after filtering). Clicking
/// a letter calls [onLetterTap] with that letter string (e.g. 'A', '0-9').
class AlphaIndexColumn extends StatelessWidget {
  final List<dynamic> apps;
  final void Function(String letter) onLetterTap;

  const AlphaIndexColumn({
    super.key,
    required this.apps,
    required this.onLetterTap,
  });

  @override
  Widget build(BuildContext context) {
    final letters = computeAlphaIndex(apps);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 28,
      child: letters.isEmpty
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              child: Column(
                children: letters.map((letter) {
                  return _AlphaLetterButton(
                    letter: letter,
                    onTap: () => onLetterTap(letter),
                    colorScheme: colorScheme,
                    isDark: isDark,
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _AlphaLetterButton extends StatefulWidget {
  final String letter;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isDark;

  const _AlphaLetterButton({
    required this.letter,
    required this.onTap,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  State<_AlphaLetterButton> createState() => _AlphaLetterButtonState();
}

class _AlphaLetterButtonState extends State<_AlphaLetterButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isMultiChar = widget.letter.length > 1; // '0-9' or '#'

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 20,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _hovered ? 26 : 22,
            height: _hovered ? 16 : 14,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.colorScheme.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.letter,
              style: TextStyle(
                fontSize: isMultiChar ? 7.5 : 10.5,
                fontWeight: _hovered ? FontWeight.w700 : FontWeight.w500,
                color: _hovered
                    ? widget.colorScheme.primary
                    : widget.isDark
                    ? Colors.white.withValues(alpha: 0.50)
                    : Colors.black.withValues(alpha: 0.42),
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
