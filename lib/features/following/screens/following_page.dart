import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:provider/provider.dart';

/// 我的关注页：展示已关注标签列表，左滑取消关注，点击跳转标签影片列表。
/// 行样式对齐「我的」子页的菜单 cell（Divider 分隔 + 标题 + chevron），
/// 左滑删除沿用与「我的收藏」页一致的交互。
class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  Future<void> _unfollow(FollowTagItem tag) async {
    final provider = context.read<FollowingTagsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取消关注标签？'),
        content: Text('确定取消关注「${tag.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await provider.unfollow(tag.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已取消关注')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FollowingTagsProvider>();
    final tags = provider.tags;
    return Scaffold(
      appBar: AppBar(title: const Text('我的关注')),
      body: tags.isEmpty
          ? const Center(child: Text('暂无关注标签'))
          : ListView.separated(
              itemCount: tags.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tag = tags[index];
                return Slidable(
                  key: ValueKey('slidable-${tag.id}'),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) => unawaited(_unfollow(tag)),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        icon: Icons.delete_outline,
                        label: '取消关注',
                      ),
                    ],
                  ),
                  child: ListTile(
                    title: Text(
                      tag.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      tag.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/following/tag/${Uri.encodeComponent(tag.value)}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
