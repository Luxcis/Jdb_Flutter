class AppRoutes {
  const AppRoutes._();

  static const String home = '/home';
  static const String rankings = '/rankings';
  static const String categories = '/categories';
  static const String actors = '/actors';
  static const String profile = '/profile';
  static const String login = '/login';
  static const String register = '/register';

  // Profile 子页面
  static const String profileWantWatch = '/profile/want-watch';
  static const String profileWatched = '/profile/watched';
  static const String profileFollowing = '/profile/following';
  static const String profileFavorites = '/profile/favorites';
  static const String profileFavoritesActors = '/profile/favorites/actors';
  static const String profileFavoritesMakers = '/profile/favorites/makers';
  static const String profileFavoritesSeries = '/profile/favorites/series';
  static const String profileFavoritesDirectors = '/profile/favorites/directors';
  static const String profileFavoritesCodes = '/profile/favorites/codes';
  static const String profileFavoritesLists = '/profile/favorites/lists';
  static const String profileLists = '/profile/lists';
  static const String profileRecent = '/profile/recent';
  static const String profileInfo = '/profile/info';
  static const String profileSettings = '/profile/settings';

  /// 需登录才能访问的路由集合。
  /// 注意：/profile 主页不需要登录，仅子页面需要。
  static const Set<String> protectedRoutes = {
    profileWantWatch,
    profileWatched,
    profileFollowing,
    profileFavorites,
    profileFavoritesActors,
    profileFavoritesMakers,
    profileFavoritesSeries,
    profileFavoritesDirectors,
    profileFavoritesCodes,
    profileFavoritesLists,
    profileLists,
    profileRecent,
    profileInfo,
  };
}
