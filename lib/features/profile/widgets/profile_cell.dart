import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 我的收藏等子页的 cell 列表脚手架：标题 + 分隔线列表。
class ProfileCellScaffold extends StatelessWidget {
  const ProfileCellScaffold({super.key, required this.title, required this.cells});

  final String title;
  final List<ProfileCell> cells;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView.separated(
      itemCount: cells.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => cells[i],
    ),
  );
}

/// 单个 cell 行：图标 + 标题 + 右箭头，可跳转路由。
class ProfileCell extends StatelessWidget {
  const ProfileCell({
    super.key,
    required this.title,
    required this.icon,
    this.route,
  });

  final String title;
  final IconData icon;
  final String? route;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: route == null ? null : () => context.push(route!),
  );
}
