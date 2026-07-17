import 'package:flutter/material.dart';

class SortSelect<T> extends StatelessWidget {
  const SortSelect({
    super.key, required this.options, required this.value, required this.onChanged,
  });
  final List<({String label, T value})> options;
  final T value;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T>(
      value: value,
      items: options.map((o) => DropdownMenuItem(value: o.value, child: Text(o.label))).toList(),
      onChanged: onChanged,
      underline: const SizedBox(),
    );
  }
}
