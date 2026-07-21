import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/routes.dart';

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
              const Text('登录后查看个人内容', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/login?from=%2Fprofile'),
                child: const Text('登录 / 注册'),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('设置'),
                leading: const Icon(Icons.settings),
                onTap: () => context.push('/profile/settings'),
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
          Container(
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Text(
                    ((auth.user ?? const {})['username'] as String? ?? '?')[0]
                        .toUpperCase(),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (auth.user ?? const {})['username'] as String? ?? '用户',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if ((auth.user ?? const {})['email'] is String)
                        Text(
                          auth.user!['email'] as String,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _Cell(
            title: '我想看的',
            subtitle: '我想看${auth.user?['want_watch_count'] ?? 0}部影片',
            icon: Icons.bookmark_border,
            onTap: () => context.push(AppRoutes.profileWantWatch),
          ),
          _Cell(
            title: '我看过的',
            subtitle: '我已看过${auth.user?['watched_count'] ?? 0}部影片',
            icon: Icons.done_all,
            onTap: () => context.push(AppRoutes.profileWatched),
          ),
          _Cell(
            title: '我的关注',
            icon: Icons.favorite_border,
            onTap: () => context.push(AppRoutes.profileFollowing),
          ),
          _Cell(
            title: '我的收藏',
            icon: Icons.collections_bookmark,
            onTap: () => context.push(AppRoutes.profileFavorites),
          ),
          _Cell(
            title: '我的清单',
            icon: Icons.list_alt,
            onTap: () => context.push(AppRoutes.profileLists),
          ),
          _Cell(
            title: '近期浏览',
            icon: Icons.history,
            onTap: () => context.push(AppRoutes.profileRecent),
          ),
          _Cell(
            title: '个人资料',
            icon: Icons.person_outline,
            onTap: () => context.push(AppRoutes.profileInfo),
          ),
          const Divider(),
          _Cell(
            title: '设置',
            icon: Icons.settings,
            onTap: () => context.push('/profile/settings'),
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
