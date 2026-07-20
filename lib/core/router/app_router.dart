import 'package:go_router/go_router.dart';
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

  static GoRouter buildForTest() => GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.login,
            builder: (c, s) => const LoginPage(),
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
        ],
      );
}
