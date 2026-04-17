import 'package:flutter/material.dart';

import 'star_rating.dart';

/// A rounded badge/chip used for genre and ovrport labels.
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 18,
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

/// Horizontal wrap of tag label chips.
class TagChips extends StatelessWidget {
  final List<String> tags;
  const TagChips({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        );
      }).toList(),
    );
  }
}
