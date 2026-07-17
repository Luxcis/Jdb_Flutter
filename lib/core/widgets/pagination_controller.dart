import 'package:flutter/foundation.dart';
import 'package:jade/core/models/paged_result.dart';

class PaginationController<T> extends ChangeNotifier {
  PaginationController({required this.fetch});
  final Future<PagedResult<T>> Function(int page) fetch;

  final List<T> _items = [];
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> fetchMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();
    try {
      final result = await fetch(_page + 1);
      _page = result.currentPage;
      _items.addAll(result.items);
      _hasMore = _page < result.totalPages;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _items.clear();
    _hasMore = true;
    notifyListeners();
    await fetchMore();
  }

  void reshuffle() {
    _items.shuffle();
    notifyListeners();
  }
}
