import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/review_movies_service.dart';

/// 管理一个影片类型 Tab 的独立分页状态。
class ReviewMoviesTabController {
  /// 创建使用给定状态、类型、初始排序与数据源的 Tab 控制器。
  ReviewMoviesTabController({
    required this.status,
    required this.type,
    required String sortBy,
    required String orderBy,
    required ReviewMoviesDataSource source,
  }) : _sortBy = sortBy,
       _orderBy = orderBy,
       _source = source {
    movies = PaginationController<MovieSummary>(fetch: _fetchPage);
  }

  /// 请求影片时使用的评鉴状态 wire value。
  final String status;

  /// 此 Tab 对应的影片类型 wire value。
  final String type;
  final ReviewMoviesDataSource _source;

  /// 此 Tab 的分页影片控制器。
  late final PaginationController<MovieSummary> movies;

  String _sortBy;
  String _orderBy;
  bool _initialized = false;

  /// 懒加载首屏，重复调用不会发起额外请求。
  Future<void> initialize() {
    if (_initialized) return Future.value();
    _initialized = true;
    return movies.fetchMore();
  }

  /// 更新排序；未初始化时仅保存条件，已初始化时保留现有影片并刷新。
  Future<void> changeSorting({
    required String sortBy,
    required String orderBy,
  }) {
    if (_sortBy == sortBy && _orderBy == orderBy) return Future.value();
    _sortBy = sortBy;
    _orderBy = orderBy;
    if (!_initialized) return Future.value();
    return movies.reloadWith(_fetchPage, preserveItems: true);
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) => _source.getMovies(
    status: status,
    type: type,
    sortBy: _sortBy,
    orderBy: _orderBy,
    page: page,
  );

  /// 释放此 Tab 的分页状态。
  void dispose() => movies.dispose();
}
