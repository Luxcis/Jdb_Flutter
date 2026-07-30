import 'dart:async';

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

  CategoryFilter _filter = const CategoryFilter(main: 'm');
  List<CategoryTagGroup> _groups = const [];
  bool _initialized = false;
  bool _tagsLoaded = false;
  bool _tagsLoading = false;
  bool _disposed = false;
  Object? _tagsError;
  Future<void>? _initializationFuture;
  Future<void>? _tagsFuture;

  CategoryFilter get filter => _filter;
  List<CategoryTagGroup> get groups => _groups;
  bool get tagsLoading => _tagsLoading;
  Object? get tagsError => _tagsError;

  List<CategoryFilterGroupOrder> get _groupOrder => _groups
      .map(
        (group) => (
          categoryId: group.categoryId,
          tagIds: group.tags.map((tag) => tag.id).toList(growable: false),
        ),
      )
      .toList(growable: false);

  Future<void> initialize() {
    if (_disposed) return Future.value();
    final initialization = _initializationFuture;
    if (initialization != null) return initialization;
    if (_initialized) return Future.value();
    _initialized = true;
    final completion = Completer<void>();
    final initialLoad = completion.future;
    _initializationFuture = initialLoad;
    unawaited(_loadInitialData(completion));
    return initialLoad;
  }

  Future<void> _loadInitialData(Completer<void> completion) async {
    try {
      await Future.wait<void>([retryTags(), movies.reloadWith(_fetchPage)]);
      completion.complete();
    } catch (error, stackTrace) {
      completion.completeError(error, stackTrace);
    }
  }

  Future<void> retryTags() {
    if (_disposed || _tagsLoaded) return Future.value();
    final pending = _tagsFuture;
    if (pending != null) return pending;
    final completion = Completer<void>();
    final load = completion.future;
    _tagsFuture = load;
    _tagsLoading = true;
    _tagsError = null;
    _notify();
    unawaited(_loadTags(completion));
    return load;
  }

  Future<void> _loadTags(Completer<void> completion) async {
    try {
      final groups = await _source.getTags(type: type);
      if (_disposed) return;
      _groups = groups;
      _tagsLoaded = true;
    } catch (error) {
      if (_disposed) return;
      _tagsError = error;
    } finally {
      if (!_disposed) {
        _tagsLoading = false;
        _tagsFuture = null;
        _notify();
      }
      completion.complete();
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
    groupOrder: _groupOrder,
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
