import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:provider/provider.dart';

/// 我的关注页：展示已关注标签列表，左滑取消关注，点击跳转标签影片列表。
class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  Future<void> _unfollow(FollowTagItem tag) async {
    final provider = context.read<FollowingTagsProvider>();
    try {
      await provider.unfollow(tag.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消关注')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败，请重试')),
      );
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
          : ListView.builder(
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                return Dismissible(
                  key: ValueKey(tag.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _unfollow(tag),
                  child: ListTile(
                    title: Text(tag.name),
                    subtitle: Text(tag.value),
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
