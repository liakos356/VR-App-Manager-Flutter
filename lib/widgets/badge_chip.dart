import 'dart:ui';
import 'package:flutter/material.dart';

import '../utils/spatial_theme.dart';
import 'star_rating.dart';

/// A pill/capsule-shaped badge chip — spatial glass style.
///
/// [isActive] adds a subtle glow in [color].
class BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;

  const BadgeChip({
    super.key,
    required this.label,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: outlined ? 0.12 : 0.22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: color.withValues(alpha: outlined ? 0.65 : 0.40),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: kGlowBlur,
                spreadRadius: kGlowSpread,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rating stars with numeric value, optionally preceded by an Ovrport badge.
class RatingRow extends StatelessWidget {
  final bool isOvrport;
  final double rating;

  const RatingRow({super.key, required this.isOvrport, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isOvrport)
          Padding(
            padding: const EdgeInsets.only(top: 12.0, right: 12.0),
            child: BadgeChip(
              label: 'Ovrport',
              color: Colors.orange,
              outlined: true,
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              children: [
                StarRating(rating: rating, size: 32),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${rating.toStringAsFixed(1).replaceAll('.0', '')}/5',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal wrap of tag label chips — spatial pill style.
class TagChips extends StatelessWidget {
  final List<String> tags;
  const TagChips({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.secondary;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((tag) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.12 : 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: accent.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
