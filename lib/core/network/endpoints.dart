// lib/core/network/endpoints.dart

/// API 路径常量。
///
/// 对应文档: docs/api/api/jdb_api_openapi.json v1.9.35-verified-20260720
///
/// ## 2026-07-20 更新摘要
/// - 修正 7 个接口的认证要求（需 BearerAuth）
/// - search_image 改为 POST（multipart/form-data 上传图片）
/// - 标记 3 个服务端 Bug 接口: /makers、/v2/tags、/users/collected_lists（返回 HTTP 500）
/// - 补充 11 个缺失的端点常量
class Endpoints {
  const Endpoints._();

  // ── 启动 ──
  static const String startup = '/api/v1/startup';
  static const String about = '/api/v1/about';

  // ── 认证 ──
  static const String sessions = '/api/v1/sessions';

  // ── 用户 (需 BearerAuth: /users GET, /users/additional) ──
  static const String users = '/api/v1/users';
  static const String usersAdditional = '/api/v1/users/additional';
  static const String usersChangePassword = '/api/v1/users/change_password';
  static const String usersChangeUsername = '/api/v1/users/change_username';
  static const String usersCollectedActors = '/api/v1/users/collected_actors';
  static const String usersCollectedCodes = '/api/v1/users/collected_codes';
  static const String usersCollectedDirectors = '/api/v1/users/collected_directors';
  // ⚠️ 服务端Bug: 该接口返回 HTTP 500
  static const String usersCollectedLists = '/api/v1/users/collected_lists';
  static const String usersCollectedMakers = '/api/v1/users/collected_makers';
  static const String usersCollectedSeries = '/api/v1/users/collected_series';
  static const String usersRecentViewed = '/api/v1/users/recent_viewed';
  static const String usersReviewMoviesV2 = '/api/v2/users/review_movies';

  // ── 影片 ──
  static const String moviesLatest = '/api/v1/movies/latest';
  static const String moviesRecommend = '/api/v1/movies/recommend';
  static const String moviesRecommendPeriods = '/api/v1/movies/recommend_periods';
  static const String moviesTop = '/api/v1/movies/top';
  static const String moviesMayAlsoLike = '/api/v1/movies/may_also_like';
  static const String moviesTags = '/api/v1/movies/tags';

  // ── 搜索 ──
  static const String searchV2 = '/api/v2/search';

  // ── 演员 ──
  static const String actors = '/api/v1/actors';
  static const String actorsRecommend = '/api/v1/actors/recommend';

  // ── 导演/片商/系列/番号 ──
  static const String directors = '/api/v1/directors';
  // ⚠️ 服务端Bug: 该接口无论传什么 type 值均返回 HTTP 500
  static const String makers = '/api/v1/makers';
  static const String series = '/api/v1/series';

  // ── 排行榜 ──
  static const String rankings = '/api/v1/rankings';
  static const String rankingsActors = '/api/v1/rankings/actors';
  static const String rankingsPlayback = '/api/v1/rankings/playback';

  // ── 评论 ──
  static const String reviewsHotly = '/api/v1/reviews/hotly';

  // ── 清单 (需 BearerAuth: GET lists, POST lists, list actions) ──
  static const String lists = '/api/v1/lists';
  static const String listsRelated = '/api/v1/lists/related';
  static const String listsSimple = '/api/v1/lists/simple';

  // ── 标签 ──
  // ⚠️ 服务端Bug: 该接口返回 HTTP 500
  static const String tagsV2 = '/api/v2/tags';

  // ── 文章 ──
  static const String articles = '/api/v1/articles';
}
