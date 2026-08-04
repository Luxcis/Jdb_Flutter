import 'package:flutter/material.dart';

class SearchEntityListTile extends StatelessWidget {
  const SearchEntityListTile({
    super.key,
    required this.name,
    required this.count,
    required this.onTap,
  });

  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
