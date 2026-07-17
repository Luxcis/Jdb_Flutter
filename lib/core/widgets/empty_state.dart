import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.message = '暂无数据', this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(color: Colors.grey.shade500)),
      ]),
    );
  }
}
