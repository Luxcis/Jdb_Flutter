import 'package:flutter/material.dart';

/// 导航栏爱心收藏按钮：空心=未收藏，实心=已收藏，busy 时禁用。
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.hasCollected,
    this.busy = false,
    required this.onPressed,
  });

  final bool hasCollected;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: hasCollected ? '取消收藏' : '收藏',
      onPressed: busy ? null : onPressed,
      icon: Icon(
        hasCollected ? Icons.favorite : Icons.favorite_border,
        color: hasCollected ? Colors.redAccent[700] : null,
      ),
    );
  }
}
