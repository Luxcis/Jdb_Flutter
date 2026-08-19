class AppRoutes {
  const AppRoutes._();

  static const String startup = '/startup';
  static const String home = '/home';
  static const String historyRecommend = '/home/history-recommend';
  static const String historyRecommendDetail =
      '/home/history-recommend/:period';
  static const String rankings = '/rankings';
  static const String categories = '/categories';
  static const String actors = '/actors';
  static const String profile = '/profile';
  static const String login = '/login';
  static const String register = '/register';
  static const String search = '/search';
  static const String searchResults = '/search/results';
  static const String actorDetail = '/actor/:id';
  static const String moviePreview = '/movie/:id/preview';
  static const String movieDetail = '/movie/:id';
  static const String articles = '/articles';
  static const String articleDetail = '/articles/:id';
  static const String reviews = '/reviews';
  static const String magnetSearch = '/search/magnet';
  static const String magnetSearchResults = '/search/magnet/results';
  static const String series = '/series';
  static const String makers = '/makers';
  static const String directors = '/directors';
  static const String commonList = '/common-list';
  static const String latestMovies = '/latest-movies';

  static String moviePreviewLocation(String movieId) =>
      '/movie/${Uri.encodeComponent(movieId)}/preview';

  static String historyRecommendDetailLocation(String period) =>
      '/home/history-recommend/${Uri.encodeComponent(period)}';

  // Profile 子页面
  static const String profileWantWatch = '/profile/want-watch';
  static const String profileWatched = '/profile/watched';
  static const String profileFollowing = '/profile/following';
  static const String profileFavorites = '/profile/favorites';
  static const String profileFavoritesActors = '/profile/favorites/actors';
  static const String profileFavoritesMakers = '/profile/favorites/makers';
  static const String profileFavoritesSeries = '/profile/favorites/series';
  static const String profileFavoritesDirectors =
      '/profile/favorites/directors';
  static const String profileFavoritesCodes = '/profile/favorites/codes';
  static const String profileFavoritesLists = '/profile/favorites/lists';
  static const String profileLists = '/profile/lists';
  static const String profileRecent = '/profile/recent';
  static const String profileSettings = '/profile/settings';
}
