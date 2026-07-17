import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key, required this.title, this.trailing, this.onTrailing, this.bold = false,
  });
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(
            fontSize: 16,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          )),
          if (trailing != null)
            TextButton(onPressed: onTrailing, child: Text(trailing!)),
        ],
      ),
    );
  }
}
