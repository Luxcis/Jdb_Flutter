import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLogged) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('登录'),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('设置'),
                leading: const Icon(Icons.settings),
                onTap: () => context.go('/profile/settings'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          _Cell(
            title: '我想看的',
            subtitle: '${auth.user?['want_watch_count'] ?? 0}部影片',
            icon: Icons.bookmark,
            onTap: () {},
          ),
          _Cell(
            title: '我看过的',
            subtitle: '${auth.user?['watched_count'] ?? 0}部影片',
            icon: Icons.done_all,
            onTap: () {},
          ),
          _Cell(
            title: '我的关注',
            icon: Icons.favorite,
            onTap: () {},
          ),
          _Cell(
            title: '我的收藏',
            icon: Icons.collections,
            onTap: () {},
          ),
          _Cell(
            title: '我的清单',
            icon: Icons.list,
            onTap: () {},
          ),
          _Cell(
            title: '近期浏览',
            icon: Icons.history,
            onTap: () {},
          ),
          _Cell(
            title: '个人资料',
            icon: Icons.person,
            onTap: () {},
          ),
          const Divider(),
          _Cell(
            title: '设置',
            icon: Icons.settings,
            onTap: () => context.go('/profile/settings'),
          ),
          ListTile(
            title: const Text('退出登录'),
            leading: const Icon(Icons.logout),
            onTap: () async {
              await auth.logout();
              if (context.mounted) context.go('/home');
            },
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _Cell({
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        leading: Icon(icon),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
