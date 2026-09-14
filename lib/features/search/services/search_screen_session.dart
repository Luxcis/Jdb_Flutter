import 'package:jade/core/models/paged_result.dart';

class SearchPageSession<T> {
  SearchPageSession({required this.fetchPage, required this.idOf});

  final Future<PagedResult<T>> Function(int page) fetchPage;
  final String Function(T item) idOf;
  final Set<String> _seenIds = {};

  Future<PagedResult<T>> fetch(int page) async {
    if (page == 1) _seenIds.clear();
    final result = await fetchPage(page);
    final newItems = result.items
        .where((item) => _seenIds.add(idOf(item)))
        .toList(growable: false);
    final stoppedByEmptyPage = page > 1 && newItems.isEmpty;
    return PagedResult(
      items: newItems,
      currentPage: result.currentPage,
      totalPages: stoppedByEmptyPage ? result.currentPage : result.totalPages,
      total: result.total,
    );
  }
}
