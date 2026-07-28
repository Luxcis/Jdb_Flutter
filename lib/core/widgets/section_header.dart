import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailing,
    this.bold = false,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  final bool bold;

  Widget get sliver => SliverToBoxAdapter(child: this);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailingContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          trailing ?? '',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
          if (trailing != null)
            InkWell(
              onTap: onTrailing,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: trailingContent,
              ),
            ),
        ],
      ),
    );
  }
}
