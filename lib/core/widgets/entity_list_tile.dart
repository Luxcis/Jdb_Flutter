import 'package:flutter/material.dart';

class EntityListTile extends StatelessWidget {
  const EntityListTile({
    super.key,
    required this.name,
    this.count,
    required this.onTap,
    this.subtitle,
  });

  final String name;

  /// 数量；为 null 时不显示 `(count)`（如关注标签无数量字段）。
  final int? count;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (count case final count?) ...[
                    Text(
                      '($count)',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
              if (subtitle case final subtitle?) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
