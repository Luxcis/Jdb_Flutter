import 'package:flutter/material.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/features/following/screens/following_page.dart';
import 'package:jade/features/profile/widgets/profile_cell.dart';

class ProfileFollowingPage extends StatelessWidget {
  const ProfileFollowingPage({super.key});

  @override
  Widget build(BuildContext context) => const FollowingPage();
}

class ProfileFavoritesPage extends StatelessWidget {
  const ProfileFavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileCellScaffold(
      title: '我的收藏',
      cells: [
        ProfileCell(
          title: '收藏的演员',
          icon: Icons.person_outline,
          route: AppRoutes.profileFavoritesActors,
        ),
        ProfileCell(
          title: '收藏的片商',
          icon: Icons.business,
          route: AppRoutes.profileFavoritesMakers,
        ),
        ProfileCell(
          title: '收藏的系列',
          icon: Icons.collections_bookmark,
          route: AppRoutes.profileFavoritesSeries,
        ),
        ProfileCell(
          title: '收藏的导演',
          icon: Icons.person_search,
          route: AppRoutes.profileFavoritesDirectors,
        ),
        ProfileCell(
          title: '收藏的番号',
          icon: Icons.confirmation_number_outlined,
          route: AppRoutes.profileFavoritesCodes,
        ),
        ProfileCell(
          title: '收藏的清单',
          icon: Icons.list_alt,
          route: AppRoutes.profileFavoritesLists,
        ),
      ],
    );
  }
}
