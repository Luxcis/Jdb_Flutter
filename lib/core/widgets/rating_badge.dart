import 'package:flutter/material.dart';

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rank});

  final int rank;

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return Color(0xFFFFD700);
      case 2:
        return Color(0xFFA8A9AD);
      case 3:
        return Color(0xFFCD7F32);
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: _rankColor(rank),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
