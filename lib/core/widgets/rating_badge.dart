import 'package:flutter/material.dart';

/// 榜单名次徽章。
///
/// 前三名使用金/银/铜底色，并搭配各自的深色前景，保证文字与底色
/// 对比度不低于 WCAG AA 4.5:1；读屏朗读“第 N 名”而不是孤立的数字。
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rank});

  final int rank;

  // 前三名底色与前景成对定义，避免未来只改其一时再次丢失对比度。
  static const _goldBackground = Color(0xFFFFD700);
  static const _goldForeground = Color(0xFF3E2C00);
  static const _silverBackground = Color(0xFFA8A9AD);
  static const _silverForeground = Color(0xFF1F2328);
  static const _bronzeBackground = Color(0xFFCD7F32);
  static const _bronzeForeground = Color(0xFF2B1600);

  Color _rankBackground(int rank) {
    switch (rank) {
      case 1:
        return _goldBackground;
      case 2:
        return _silverBackground;
      case 3:
        return _bronzeBackground;
      default:
        return Colors.black54;
    }
  }

  Color _rankForeground(int rank) {
    switch (rank) {
      case 1:
        return _goldForeground;
      case 2:
        return _silverForeground;
      case 3:
        return _bronzeForeground;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '第 $rank 名',
      // 只朗读一次“第 N 名”，不再额外朗读数字本身。
      excludeSemantics: true,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: _rankBackground(rank),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: TextStyle(
            color: _rankForeground(rank),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
