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
import 'package:jade/features/following/index.dart';

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
      builder: (context, state) => const StartupScreen(),
    ),
    GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
    GoRoute(path: AppRoutes.register, builder: (c, s) => const RegisterScreen()),
    GoRoute(
      path: AppRoutes.historyRecommend,
      builder: (c, s) => const HistoryRecommendScreen(),
    ),
    GoRoute(
      path: AppRoutes.historyRecommendDetail,
      builder: (c, s) =>
          HistoryRecommendDetailScreen(period: s.pathParameters['period']!),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: AppRoutes.home, builder: (c, s) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.rankings,
              builder: (context, state) => RankingsScreen(
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
              builder: (c, s) => const CategoriesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.actors,
              builder: (c, s) => const ActorsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (c, s) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.moviePreview,
      builder: (context, state) => MoviePreviewScreen(
        args: state.extra is MoviePreviewArgs
            ? state.extra! as MoviePreviewArgs
            : null,
      ),
    ),
    GoRoute(
      path: AppRoutes.movieDetail,
      builder: (c, s) => MovieDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.actorDetail,
      builder: (c, s) => ActorDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.search,
      builder: (c, s) => const SearchScreen(),
      routes: [
        GoRoute(
          path: 'results',
          redirect: (context, state) {
            final query = state.uri.queryParameters['q']?.trim() ?? '';
            return query.isEmpty ? AppRoutes.search : null;
          },
          // 页面键需包含 query：pageKey 仅由路径决定，修改关键词后
          // replace 到同路径不同 q 不会重建页面、不会重新搜索。
          builder: (context, state) => SearchResultsScreen(
            key: ValueKey(state.uri),
            query: state.uri.queryParameters['q']!.trim(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.articles,
      builder: (c, s) => const ArticlesScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (c, s) => ArticleDetailScreen(id: s.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(path: AppRoutes.reviews, builder: (c, s) => const ReviewsScreen()),
    GoRoute(
      path: AppRoutes.magnetSearch,
      builder: (context, state) => const MagnetSearchScreen(),
      routes: [
        GoRoute(
          path: 'results',
          redirect: (context, state) {
            final query = state.uri.queryParameters['q']?.trim() ?? '';
            return query.isEmpty ? AppRoutes.magnetSearch : null;
          },
          builder: (context, state) => MagnetSearchResultsScreen(
            key: ValueKey(state.uri),
            query: state.uri.queryParameters['q']!.trim(),
            fromRecent:
                state.uri.queryParameters['from_recent']?.toLowerCase() ==
                'true',
          ),
        ),
      ],
    ),
    GoRoute(path: AppRoutes.series, builder: (c, s) => const SeriesScreen()),
    GoRoute(path: AppRoutes.makers, builder: (c, s) => const MakersScreen()),
    GoRoute(
      path: AppRoutes.directors,
      builder: (c, s) => const DirectorsScreen(),
    ),
    GoRoute(
      path: AppRoutes.commonList,
      builder: (c, s) {
        final q = s.uri.queryParameters;
        return CommonListScreen(
          title: q['title'] ?? '',
          type: int.tryParse(q['type'] ?? '') ?? 0,
          category: q['category'] ?? '',
          id: q['id'] ?? '',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.latestMovies,
      builder: (c, s) {
        final q = s.uri.queryParameters;
        return LatestMoviesScreen(
          section: q['section'] ?? 'latest',
          title: q['title'] ?? '最新影片',
        );
      },
    ),
    GoRoute(
      path: AppRoutes.profileWantWatch,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileWantWatch,
        child: const ProfileReviewMoviesScreen(
          title: '我想看的',
          status: 'want_watch',
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileWatched,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileWatched,
        child: const ProfileMovieCollectionScreen(
          title: '我看过的',
          filterButton: true,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFollowing,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFollowing,
        child: const ProfileFollowingScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavorites,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavorites,
        child: const ProfileFavoritesScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesActors,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesActors,
        child: const CollectedActorsScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesMakers,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesMakers,
        child: const CollectedEntitiesScreen(category: 'm', title: '收藏的片商'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesSeries,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesSeries,
        child: const CollectedEntitiesScreen(category: 's', title: '收藏的系列'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesDirectors,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesDirectors,
        child: const CollectedEntitiesScreen(category: 'd', title: '收藏的导演'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesCodes,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesCodes,
        child: const CollectedEntitiesScreen(category: 'c', title: '收藏的番号'),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileFavoritesLists,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileFavoritesLists,
        child: const CollectedListsScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileLists,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileLists,
        child: const MyListsScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileRecent,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileRecent,
        child: const ProfileRecentViewedScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileSettings,
      builder: (c, s) => const ProfileSettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.followTagMovies,
      builder: (c, s) => FollowTagMoviesScreen(
        value: Uri.decodeComponent(s.pathParameters['value']!),
      ),
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
