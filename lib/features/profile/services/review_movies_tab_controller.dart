import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/review_movies_service.dart';

class ReviewMoviesTabController {
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

  final String status;
  final String type;
  final ReviewMoviesDataSource _source;
  late final PaginationController<MovieSummary> movies;

  String _sortBy;
  String _orderBy;
  bool _initialized = false;

  Future<void> initialize() {
    if (_initialized) return Future.value();
    _initialized = true;
    return movies.fetchMore();
  }

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

  void dispose() => movies.dispose();
}
