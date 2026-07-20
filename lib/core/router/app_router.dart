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
    final loc = state.uri.path;

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
      ];
}
