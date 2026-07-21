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
  static GoRouter build({String initialLocation = AppRoutes.home}) => GoRouter(
    initialLocation: initialLocation,
    redirect: _redirect,
    routes: _routes,
  );

  /// 测试用路由（无 redirect，避免测试依赖 AuthProvider）。
  static GoRouter buildForTest({String initialLocation = AppRoutes.home}) =>
      GoRouter(initialLocation: initialLocation, routes: _routes);

  static String? _redirect(BuildContext context, GoRouterState state) {
    final auth = context.read<AuthProvider>();
    final isLogged = auth.isLogged;
    final loc = state.matchedLocation;

    if (isLogged && (loc == AppRoutes.login || loc == AppRoutes.register)) {
      return AppRoutes.home;
    }

    if (!isLogged && AppRoutes.protectedRoutes.contains(loc)) {
      return '${AppRoutes.login}?from=$loc';
    }

    return null;
  }

  static List<RouteBase> get _routes => [
    GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginPage()),
    GoRoute(path: AppRoutes.register, builder: (c, s) => const RegisterPage()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: AppRoutes.home, builder: (c, s) => const HomePage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.rankings,
              builder: (c, s) => const RankingsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.categories,
              builder: (c, s) => const CategoriesPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.actors,
              builder: (c, s) => const ActorsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (c, s) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.movieDetail,
      builder: (c, s) => MovieDetailPage(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.actorDetail,
      builder: (c, s) => ActorDetailPage(id: s.pathParameters['id']!),
    ),
    GoRoute(path: AppRoutes.search, builder: (c, s) => const SearchPage()),
    GoRoute(
      path: AppRoutes.articles,
      builder: (c, s) => const _SimpleListPage(title: 'AV资讯'),
    ),
    GoRoute(
      path: AppRoutes.reviews,
      builder: (c, s) => const _SimpleListPage(title: '看短评'),
    ),
    GoRoute(
      path: AppRoutes.magnetSearch,
      builder: (c, s) => const _SimpleListPage(title: '找磁链'),
    ),
    GoRoute(
      path: AppRoutes.imageSearch,
      builder: (c, s) => const _SimpleListPage(title: '识别搜索'),
    ),
    GoRoute(
      path: AppRoutes.series,
      builder: (c, s) => const _SimpleListPage(title: '系列'),
    ),
    GoRoute(
      path: AppRoutes.makers,
      builder: (c, s) => const _SimpleListPage(title: '片商'),
    ),
    GoRoute(
      path: AppRoutes.directors,
      builder: (c, s) => const _SimpleListPage(title: '导演'),
    ),
    GoRoute(
      path: AppRoutes.profileWantWatch,
      builder: (c, s) =>
          const ProfileMovieCollectionPage(title: '我想看的', filterButton: true),
    ),
    GoRoute(
      path: AppRoutes.profileWatched,
      builder: (c, s) =>
          const ProfileMovieCollectionPage(title: '我看过的', filterButton: true),
    ),
    GoRoute(
      path: AppRoutes.profileFollowing,
      builder: (c, s) => const ProfileFollowingPage(),
    ),
    GoRoute(
      path: AppRoutes.profileFavorites,
      builder: (c, s) => const ProfileFavoritesPage(),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesActors,
      builder: (c, s) => const ProfileFavoriteActorsPage(),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesMakers,
      builder: (c, s) => const ProfileNamedCollectionPage(title: '收藏的片商'),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesSeries,
      builder: (c, s) => const ProfileNamedCollectionPage(title: '收藏的系列'),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesDirectors,
      builder: (c, s) => const ProfileNamedCollectionPage(title: '收藏的导演'),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesCodes,
      builder: (c, s) => const ProfileNamedCollectionPage(title: '收藏的番号'),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesLists,
      builder: (c, s) => const ProfileNamedCollectionPage(title: '收藏的清单'),
    ),
    GoRoute(
      path: AppRoutes.profileLists,
      builder: (c, s) => const ProfileNamedCollectionPage(title: '我的清单'),
    ),
    GoRoute(
      path: AppRoutes.profileRecent,
      builder: (c, s) => const ProfileMovieCollectionPage(title: '近期浏览'),
    ),
    GoRoute(
      path: AppRoutes.profileInfo,
      builder: (c, s) => const ProfileInfoPage(),
    ),
    GoRoute(
      path: AppRoutes.profileSettings,
      builder: (c, s) => const ProfileSettingsPage(),
    ),
  ];
}

class _SimpleListPage extends StatelessWidget {
  const _SimpleListPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView.separated(
      itemCount: 8,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => ListTile(
        title: Text('$title ${i + 1}'),
        subtitle: const Text('内容接入接口后展示'),
        trailing: const Icon(Icons.chevron_right),
      ),
    ),
  );
}
