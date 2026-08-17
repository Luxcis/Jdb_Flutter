import 'package:flutter/material.dart';

class SortSelect<T> extends StatelessWidget {
  const SortSelect({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.compact = false,
  });

  final List<({String label, T value})> options;
  final T value;
  final ValueChanged<T?>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return PopupMenuButton<T>(
        initialValue: value,
        onSelected: (selected) => onChanged?.call(selected),
        enabled: onChanged != null,
        itemBuilder: (_) => [
          for (final option in options)
            PopupMenuItem(value: option.value, child: Text(option.label)),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                options.firstWhere((option) => option.value == value).label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    }
    return DropdownButton<T>(
      value: value,
      items: options
          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
          .toList(),
      onChanged: onChanged,
      underline: const SizedBox(),
    );
  }
}
