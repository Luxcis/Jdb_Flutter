import 'package:flutter/material.dart';
import 'package:jade/core/models/list_model.dart';

class ListSummaryTile extends StatelessWidget {
  const ListSummaryTile({
    super.key,
    required this.list,
    this.onTap,
    this.showViewCount = true,
  });

  final ListModel list;
  final VoidCallback? onTap;
  final bool showViewCount;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
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
