import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/router/routes.dart';

class ListSummaryTile extends StatelessWidget {
  const ListSummaryTile({
    super.key,
    required this.list,
    this.onTap,
    this.showViewCount = true,
  });

  final ListModel list;

  /// 覆盖默认的清单页跳转；为 null 时点击默认打开该清单的影片列表页。
  final VoidCallback? onTap;
  final bool showViewCount;

  void _openListPage(BuildContext context) {
    context.push(
      Uri(
        path: AppRoutes.commonList,
        queryParameters: {
          'title': '清单 - ${list.name}',
          'type': '0',
          'category': 'l',
          'id': list.id,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap ?? () => _openListPage(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    title: Text(
      list.name,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        showViewCount
            ? '${list.movieCount} 部影片，被查看 ${list.viewedCount} 次'
            : '${list.movieCount} 部影片',
      ),
    ),
    trailing: const Icon(Icons.chevron_right),
  );
}
