import 'package:flutter/material.dart';

class SortSegmented<T> extends StatelessWidget {
  const SortSegmented({
    super.key, required this.options, required this.value, required this.onChanged,
  });
  final List<({String label, T value})> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: options.map((o) => ButtonSegment<T>(value: o.value, label: Text(o.label))).toList(),
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
