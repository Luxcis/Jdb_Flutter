import 'package:flutter/material.dart';

class SortSegmented<T> extends StatelessWidget {
  const SortSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.expanded = false,
  });

  final List<({String label, T value})> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: options
          .map(
            (option) => ButtonSegment<T>(
              value: option.value,
              label: Text(option.label),
            ),
          )
          .toList(),
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
      expandedInsets: expanded ? EdgeInsets.zero : null,
      showSelectedIcon: !compact,
      style: compact
          ? const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8),
              ),
            )
          : null,
    );
  }
}
