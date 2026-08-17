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
        child: Text(
          options.firstWhere((option) => option.value == value).label,
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
