import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginGuideCard extends StatelessWidget {
  const LoginGuideCard({
    super.key,
    required this.message,
    this.loginPath = '',
  });

  final String message;
  final String loginPath;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    final from = loginPath.isNotEmpty
                        ? '?from=$loginPath'
                        : '';
                    context.go('/login$from');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('去登录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
