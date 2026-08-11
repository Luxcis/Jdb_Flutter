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
import 'package:jade/features/articles/index.dart';
import 'package:jade/features/profile/index.dart';
import 'package:jade/features/movie_detail/index.dart';
import 'package:jade/features/makers/index.dart';
import 'package:jade/features/directors/index.dart';
import 'package:jade/features/search/index.dart';
import 'package:jade/features/auth/index.dart';
import 'package:jade/features/startup/index.dart';
import 'package:jade/features/reviews/index.dart';
import 'package:jade/features/series/index.dart';
import 'package:jade/features/common/index.dart';

class AppRouter {
  const AppRouter._();

  static GoRouter? _activeRouter;
  static bool _allowAuthErrorLoginOnce = false;

  /// 生产用路由（含 auth redirect）。
  static GoRouter build({String initialLocation = AppRoutes.startup}) =>
      _remember(
        GoRouter(
          initialLocation: initialLocation,
          redirect: _redirect,
          routes: _routes,
        ),
      );

  /// 测试用路由（无 redirect，避免测试依赖 AuthProvider）。
  static GoRouter buildForTest({String initialLocation = AppRoutes.home}) =>
      _remember(GoRouter(initialLocation: initialLocation, routes: _routes));

  static GoRouter _remember(GoRouter router) {
    _activeRouter = router;
    return router;
  }

  static void goLoginForAuthError() {
    final router = _activeRouter;
    if (router == null) return;
    final matchedLocation = router.state.matchedLocation;
    if (matchedLocation == AppRoutes.login ||
        matchedLocation == AppRoutes.register) {
      return;
    }
    final from = router.state.uri.toString();
    _allowAuthErrorLoginOnce = true;
    router.push(
      Uri(path: AppRoutes.login, queryParameters: {'from': from}).toString(),
    );
  }

  static String? _redirect(BuildContext context, GoRouterState state) {
    final auth = context.read<AuthProvider>();
    final isLogged = auth.isLogged;
    final loc = state.matchedLocation;

    if (_allowAuthErrorLoginOnce && loc == AppRoutes.login) {
      _allowAuthErrorLoginOnce = false;
      return null;
    }

    if (isLogged && (loc == AppRoutes.login || loc == AppRoutes.register)) {
      return AppRoutes.home;
    }

    return null;
  }

  static List<RouteBase> get _routes => [
    GoRoute(
      path: AppRoutes.startup,
      builder: (context, state) => const StartupPage(),
    ),
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
              builder: (context, state) => RankingsPage(
                initialTabIndex: state.uri.queryParameters['tab'] == 'hot'
                    ? 1
                    : 2,
              ),
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
      path: AppRoutes.moviePreview,
      builder: (context, state) => MoviePreviewPage(
        args: state.extra is MoviePreviewArgs
            ? state.extra! as MoviePreviewArgs
            : null,
      ),
    ),
    GoRoute(
      path: AppRoutes.movieDetail,
      builder: (c, s) => MovieDetailPage(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.actorDetail,
      builder: (c, s) => ActorDetailPage(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.search,
      builder: (c, s) => const SearchPage(),
      routes: [
        GoRoute(
          path: 'results',
          redirect: (context, state) {
            final query = state.uri.queryParameters['q']?.trim() ?? '';
            return query.isEmpty ? AppRoutes.search : null;
          },
          builder: (context, state) => SearchResultsPage(
            key: state.pageKey,
            query: state.uri.queryParameters['q']!.trim(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.articles,
      builder: (c, s) => const ArticlesPage(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (c, s) => ArticleDetailPage(id: s.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(path: AppRoutes.reviews, builder: (c, s) => const ReviewsPage()),
    GoRoute(
      path: AppRoutes.magnetSearch,
      builder: (context, state) => const MagnetSearchPage(),
      routes: [
        GoRoute(
          path: 'results',
          redirect: (context, state) {
            final query = state.uri.queryParameters['q']?.trim() ?? '';
            return query.isEmpty ? AppRoutes.magnetSearch : null;
          },
          builder: (context, state) => MagnetSearchResultsPage(
            key: state.pageKey,
            query: state.uri.queryParameters['q']!.trim(),
            fromRecent:
                state.uri.queryParameters['from_recent']?.toLowerCase() ==
                'true',
          ),
        ),
      ],
    ),
    GoRoute(path: AppRoutes.series, builder: (c, s) => const SeriesPage()),
    GoRoute(path: AppRoutes.makers, builder: (c, s) => const MakersPage()),
    GoRoute(
      path: AppRoutes.directors,
      builder: (c, s) => const DirectorsPage(),
    ),
    GoRoute(
      path: AppRoutes.commonList,
      builder: (c, s) {
        final q = s.uri.queryParameters;
        return CommonListPage(
          title: q['title'] ?? '',
          type: int.tryParse(q['type'] ?? '') ?? 0,
          category: q['category'] ?? '',
          id: q['id'] ?? '',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.profileWantWatch,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileWantWatch,
        child: const ProfileMovieCollectionPage(
          title: '我想看的',
          filterButton: true,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileWatched,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileWatched,
        child: const ProfileMovieCollectionPage(
          title: '我看过的',
          filterButton: true,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFollowing,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFollowing,
        child: const ProfileFollowingPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavorites,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavorites,
        child: const ProfileFavoritesPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesActors,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesActors,
        child: const ProfileFavoriteActorsPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesMakers,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesMakers,
        child: const ProfileNamedCollectionPage(title: '收藏的片商'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesSeries,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesSeries,
        child: const ProfileNamedCollectionPage(title: '收藏的系列'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesDirectors,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesDirectors,
        child: const ProfileNamedCollectionPage(title: '收藏的导演'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesCodes,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesCodes,
        child: const ProfileNamedCollectionPage(title: '收藏的番号'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesLists,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesLists,
        child: const ProfileNamedCollectionPage(title: '收藏的清单'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileLists,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileLists,
        child: const ProfileNamedCollectionPage(title: '我的清单'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileRecent,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileRecent,
        child: const ProfileMovieCollectionPage(title: '近期浏览'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileInfo,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileInfo,
        child: const ProfileInfoPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileSettings,
      builder: (c, s) => const ProfileSettingsPage(),
    ),
  ];
}

class _AuthGuard extends StatefulWidget {
  final Widget child;
  final String route;
  const _AuthGuard({required this.child, required this.route});

  @override
  State<_AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<_AuthGuard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!mounted || auth.isLogged) return;
      context.push('${AppRoutes.login}?from=${widget.route}');
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
