// lib/core/network/endpoints.dart

/// API 路径常量（取自 docs/api/api/api-reference.md）。
class Endpoints {
  const Endpoints._();
  static const String startup = '/api/v1/startup';
  static const String about = '/api/v1/about';
  static const String sessions = '/api/v1/sessions';
  static const String users = '/api/v1/users';
  static const String usersAdditional = '/api/v1/users/additional';
  static const String moviesLatest = '/api/v1/movies/latest';
  static const String moviesRecommend = '/api/v1/movies/recommend';
  static const String moviesRecommendPeriods = '/api/v1/movies/recommend_periods';
  static const String moviesTop = '/api/v1/movies/top';
  static const String moviesMayAlsoLike = '/api/v1/movies/may_also_like';
  static const String moviesTags = '/api/v1/movies/tags';
  static const String searchV2 = '/api/v2/search';
  static const String searchImage = '/api/v2/search_image';
  static const String searchMagnet = '/api/v1/search_magnet';
  static const String actors = '/api/v1/actors';
  static const String actorsRecommend = '/api/v1/actors/recommend';
  static const String directors = '/api/v1/directors';
  static const String makers = '/api/v1/makers';
  static const String series = '/api/v1/series';
  static const String rankings = '/api/v1/rankings';
  static const String rankingsActors = '/api/v1/rankings/actors';
  static const String rankingsPlayback = '/api/v1/rankings/playback';
  static const String reviewsHotly = '/api/v1/reviews/hotly';
  static const String lists = '/api/v1/lists';
  static const String tagsV2 = '/api/v2/tags';
  static const String articles = '/api/v1/articles';
}
