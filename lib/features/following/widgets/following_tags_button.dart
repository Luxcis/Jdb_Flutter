import 'package:flutter/material.dart';

/// 类别页导航栏「关注标签」按钮。
/// [following] 是否已关注；[enabled] 是否有可关注的已选标签；[busy] 请求中禁用。
class FollowingTagsButton extends StatelessWidget {
  const FollowingTagsButton({
    super.key,
    required this.following,
    required this.enabled,
    this.busy = false,
    required this.onPressed,
  });

  final bool following;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: following ? '取消关注' : '关注',
      onPressed: busy || !enabled ? null : onPressed,
      icon: Icon(following ? Icons.visibility_off : Icons.visibility),
    );
  }
}
