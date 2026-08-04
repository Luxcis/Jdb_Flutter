import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/search/services/search_page_session.dart';

void main() {
  test('重复下一页不追加并终止分页', () async {
    final pages = <int, PagedResult<_Item>>{
      1: const PagedResult(
        items: [_Item('1'), _Item('2')],
        currentPage: 1,
        totalPages: 3,
        total: 4,
      ),
      2: const PagedResult(
        items: [_Item('1'), _Item('2')],
        currentPage: 2,
        totalPages: 3,
        total: 4,
      ),
    };
    final session = SearchPageSession<_Item>(
      fetchPage: (page) async => pages[page]!,
      idOf: (item) => item.id,
    );

    final first = await session.fetch(1);
    final second = await session.fetch(2);

    expect(first.items.map((item) => item.id), ['1', '2']);
    expect(second.items, isEmpty);
    expect(second.currentPage, second.totalPages);
  });

  test('重新请求第一页会清空已见 ID', () async {
    const page = PagedResult(
      items: [_Item('1')],
      currentPage: 1,
      totalPages: 1,
      total: 1,
    );
    final session = SearchPageSession<_Item>(
      fetchPage: (_) async => page,
      idOf: (item) => item.id,
    );

    expect((await session.fetch(1)).items, hasLength(1));
    expect((await session.fetch(1)).items, hasLength(1));
  });

  test('第一页空结果保留页码但后续空页终止分页', () async {
    final pages = <int, PagedResult<_Item>>{
      1: const PagedResult(items: [], currentPage: 1, totalPages: 3, total: 0),
      2: const PagedResult(items: [], currentPage: 2, totalPages: 3, total: 0),
    };
    final session = SearchPageSession<_Item>(
      fetchPage: (page) async => pages[page]!,
      idOf: (item) => item.id,
    );

    final first = await session.fetch(1);
    final second = await session.fetch(2);

    expect(first.items, isEmpty);
    expect(first.totalPages, 3);
    expect(second.items, isEmpty);
    expect(second.currentPage, second.totalPages);
  });
}

class _Item {
  const _Item(this.id);

  final String id;
}
