import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/main_shell.dart';
import 'package:jade/features/home/index.dart';
import 'package:jade/features/rankings/index.dart';
import 'package:jade/features/categories/index.dart';
import 'package:jade/features/actors/index.dart';
import 'package:jade/features/profile/index.dart';
import 'package:jade/features/movie_detail/index.dart';
import 'package:jade/features/search/index.dart';
import 'package:jade/features/auth/index.dart';

class AppRouter {
  const AppRouter._();

  /// 生产用路由（含 auth redirect）。
  static GoRouter build() => GoRouter(
        initialLocation: AppRoutes.home,
        redirect: _redirect,
        routes: _routes,
      );

  /// 测试用路由（无 redirect，避免测试依赖 AuthProvider）。
  static GoRouter buildForTest() => GoRouter(
        initialLocation: AppRoutes.home,
        routes: _routes,
      );

  static String? _redirect(BuildContext context, GoRouterState state) {
    final auth = context.read<AuthProvider>();
    final isLogged = auth.isLogged;
    final loc = state.matchedLocation;

    if (isLogged &&
        (loc == AppRoutes.login || loc == AppRoutes.register)) {
      return AppRoutes.home;
    }

    if (!isLogged && AppRoutes.protectedRoutes.contains(loc)) {
      return '${AppRoutes.login}?from=$loc';
    }

    return null;
  }

  static List<RouteBase> get _routes => [
        GoRoute(
          path: AppRoutes.login,
          builder: (c, s) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (c, s) => const RegisterPage(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              MainShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.home,
                  builder: (c, s) => const HomePage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.rankings,
                  builder: (c, s) => const RankingsPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.categories,
                  builder: (c, s) => const CategoriesPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.actors,
                  builder: (c, s) => const ActorsPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: AppRoutes.profile,
                  builder: (c, s) => const ProfilePage()),
            ]),
          ],
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (c, s) =>
              MovieDetailPage(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/search',
          builder: (c, s) => const SearchPage(),
        ),
        // Profile 子页面占位路由（redirect 守卫依赖这些路由存在）
        GoRoute(
          path: AppRoutes.profileWantWatch,
          builder: (c, s) => const _GatedPage(title: '我想看的'),
        ),
        GoRoute(
          path: AppRoutes.profileWatched,
          builder: (c, s) => const _GatedPage(title: '我看过的'),
        ),
        GoRoute(
          path: AppRoutes.profileFollowing,
          builder: (c, s) => const _GatedPage(title: '我的关注'),
        ),
        GoRoute(
          path: AppRoutes.profileFavorites,
          builder: (c, s) => const _GatedPage(title: '我的收藏'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesActors,
          builder: (c, s) => const _GatedPage(title: '收藏的演员'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesMakers,
          builder: (c, s) => const _GatedPage(title: '收藏的片商'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesSeries,
          builder: (c, s) => const _GatedPage(title: '收藏的系列'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesDirectors,
          builder: (c, s) => const _GatedPage(title: '收藏的导演'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesCodes,
          builder: (c, s) => const _GatedPage(title: '收藏的番号'),
        ),
        GoRoute(
          path: AppRoutes.profileFavoritesLists,
          builder: (c, s) => const _GatedPage(title: '收藏的清单'),
        ),
        GoRoute(
          path: AppRoutes.profileLists,
          builder: (c, s) => const _GatedPage(title: '我的清单'),
        ),
        GoRoute(
          path: AppRoutes.profileRecent,
          builder: (c, s) => const _GatedPage(title: '近期浏览'),
        ),
        GoRoute(
          path: AppRoutes.profileInfo,
          builder: (c, s) => const _GatedPage(title: '个人资料'),
        ),
        GoRoute(
          path: AppRoutes.profileSettings,
          builder: (c, s) => const _GatedPage(title: '设置'),
        ),
      ];
}

class _GatedPage extends StatelessWidget {
  const _GatedPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const SizedBox(),
      );
}
