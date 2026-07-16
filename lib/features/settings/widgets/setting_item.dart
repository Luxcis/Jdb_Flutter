import 'package:flutter/material.dart';

class SettingItem extends StatelessWidget {
  const SettingItem({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.editor,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? editor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 18)),
        leading: Icon(icon),
        trailing: editor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
