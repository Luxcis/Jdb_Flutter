import 'package:flutter/foundation.dart';
import 'package:jade/core/models/paged_result.dart';

typedef PageFetcher<T> = Future<PagedResult<T>> Function(int page);

class PaginationController<T> extends ChangeNotifier {
  PaginationController({required PageFetcher<T> fetch}) : _fetch = fetch;

  PageFetcher<T> _fetch;
  final List<T> _items = [];
  int _page = 0;
  int _generation = 0;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _pendingRefresh = false;
  bool _hasMore = true;
  Object? _error;

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get hasMore => _hasMore;
  Object? get error => _error;

  Future<void> fetchMore() async {
    if (_isLoading || !_hasMore) return;
    final generation = _generation;
    final fetch = _fetch;
    final requestedPage = _page + 1;
    _isLoading = true;
    _isRefreshing = _pendingRefresh;
    _error = null;
    notifyListeners();
    try {
      final result = await fetch(requestedPage);
      if (generation != _generation) return;
      _page = result.currentPage;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        _items.clear();
      }
      _items.addAll(result.items);
      _hasMore = _page < result.totalPages;
    } catch (error) {
      if (generation == _generation) _error = error;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  Future<void> reloadWith(
    PageFetcher<T> fetch, {
    bool preserveItems = false,
  }) async {
    _generation++;
    _fetch = fetch;
    _page = 0;
    if (!preserveItems) _items.clear();
    _pendingRefresh = preserveItems && _items.isNotEmpty;
    _hasMore = true;
    _isLoading = false;
    _isRefreshing = false;
    _error = null;
    notifyListeners();
    await fetchMore();
  }

  Future<void> refresh({bool preserveItems = true}) =>
      reloadWith(_fetch, preserveItems: preserveItems);

  void reshuffle() {
    _items.shuffle();
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
