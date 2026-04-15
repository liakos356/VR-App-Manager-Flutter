import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final double size;

  const StarRating({super.key, required this.rating, this.size = 14.0});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        IconData icon = Icons.star_border;
        Color color = Colors.grey[400]!;

        if (index < rating.floor()) {
          icon = Icons.star;
          color = Colors.amber;
        } else if (index == rating.floor() && rating - index >= 0.25) {
          icon = Icons.star_half;
          color = Colors.amber;
        }

        return Icon(icon, size: size, color: color);
      }),
    );
  }
}
