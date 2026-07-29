import 'package:flutter/foundation.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';
import 'package:jade/features/categories/services/category_service.dart';

class CategoryTabController extends ChangeNotifier {
  CategoryTabController({
    required this.type,
    required CategoryDataSource source,
  }) : _source = source,
       movies = PaginationController<MovieSummary>(
         fetch: (_) => throw StateError('controller not initialized'),
       ) {
    movies.addListener(_notifyFromMovies);
  }

  final int type;
  final CategoryDataSource _source;
  final PaginationController<MovieSummary> movies;

  CategoryFilter _filter = const CategoryFilter();
  List<CategoryTagGroup> _groups = const [];
  bool _initialized = false;
  bool _tagsLoading = false;
  bool _disposed = false;
  Object? _tagsError;

  CategoryFilter get filter => _filter;
  List<CategoryTagGroup> get groups => _groups;
  bool get tagsLoading => _tagsLoading;
  Object? get tagsError => _tagsError;

  List<String> get _categoryOrder =>
      _groups.map((group) => group.categoryId).toList(growable: false);

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await Future.wait([retryTags(), movies.reloadWith(_fetchPage)]);
  }

  Future<void> retryTags() async {
    if (_tagsLoading || _disposed) return;
    _tagsLoading = true;
    _tagsError = null;
    _notify();
    try {
      _groups = await _source.getTags(type: type);
    } catch (error) {
      _tagsError = error;
    } finally {
      _tagsLoading = false;
      _notify();
    }
  }

  Future<void> toggleFilter(String categoryId, String value) async {
    if (_disposed) return;
    _filter = _filter.toggle(categoryId, value);
    _notify();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  Future<void> changeSort(CategorySort sort) async {
    if (_disposed) return;
    _filter = _filter.copyWith(sort: sort);
    _notify();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  Future<void> toggleOrder() async {
    if (_disposed) return;
    _filter = _filter.copyWith(
      orderBy: _filter.orderBy == 'desc' ? 'asc' : 'desc',
    );
    _notify();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) => _source.getMovies(
    type: type,
    filter: _filter,
    categoryOrder: _categoryOrder,
    page: page,
  );

  void _notifyFromMovies() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    movies.removeListener(_notifyFromMovies);
    movies.dispose();
    super.dispose();
  }
}
