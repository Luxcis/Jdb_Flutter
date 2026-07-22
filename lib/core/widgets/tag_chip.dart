import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.compact = false,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      visualDensity: compact ? VisualDensity.compact : null,
      materialTapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
      labelStyle: compact ? Theme.of(context).textTheme.labelSmall : null,
      padding: compact ? EdgeInsets.zero : null,
      labelPadding: compact ? const EdgeInsets.symmetric(horizontal: 6) : null,
    );
  }
}
