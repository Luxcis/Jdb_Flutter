import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_segmented.dart';

import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/common/services/tag_movies_service.dart';

typedef _Call = ({
  int type,
  String category,
  String id,
  String filter,
  String sortBy,
  String orderBy,
  int page,
});

class _RecordingTagMoviesDataSource implements TagMoviesDataSource {
  final calls = <_Call>[];

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required String category,
    required String id,
    required String filter,
    required String sortBy,
    String orderBy = 'desc',
    int page = 1,
  }) async {
    calls.add((
      type: type,
      category: category,
      id: id,
      filter: filter,
      sortBy: sortBy,
      orderBy: orderBy,
      page: page,
    ));
    return PagedResult(
      items: const [],
      currentPage: page,
      totalPages: page,
      total: 0,
    );
  }
}

void main() {
  testWidgets('两行布局各占整行且首屏默认含磁链热度', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '系列 - Madonna',
          type: 2,
          category: 's',
          id: 's1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('系列 - Madonna'), findsOneWidget);
    final filterRow = tester.getTopLeft(
      find.byKey(const Key('common-list-filter')),
    );
    final sortRow = tester.getTopLeft(
      find.byKey(const Key('common-list-sort')),
    );
    expect(sortRow.dy, greaterThan(filterRow.dy));
    expect(
      tester
          .widget<SortSegmented<String>>(
            find.byKey(const Key('common-list-filter')),
          )
          .value,
      'magnet',
    );
    final call = source.calls.single;
    expect(call.filter, 'm');
    expect(call.sortBy, 'hit');
    expect(call.type, 2);
    expect(call.category, 's');
    expect(call.id, 's1');
    expect(find.byType(MovieGridView), findsOneWidget);
  });

  testWidgets('清单默认排序为存入时间', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '清单 - 收藏精选',
          type: 0,
          category: 'l',
          id: 'list-1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(source.calls.single.sortBy, 'update');
    expect(find.text('存入时间'), findsOneWidget);
    await tester.tap(find.byKey(const Key('common-list-sort')));
    await tester.pumpAndSettle();
    expect(find.text('创建时间'), findsOneWidget);
    expect(find.text('评分'), findsOneWidget);
    expect(find.text('热度'), findsNothing);
    expect(find.text('番号'), findsNothing);
  });

  testWidgets('番号排序选项含番号', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '番号 - IPZZ',
          type: 0,
          category: 'c',
          id: 'IPZZ',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(source.calls.single.sortBy, 'hit');
    await tester.tap(find.byKey(const Key('common-list-sort')));
    await tester.pumpAndSettle();
    expect(find.text('番号').last, findsOneWidget);
  });

  testWidgets('切换筛选全部后去掉 filter 段并重新加载', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '系列 - Madonna',
          type: 2,
          category: 's',
          id: 's1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.calls, hasLength(1));

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();

    expect(source.calls, hasLength(2));
    expect(source.calls.last.filter, '');
    expect(source.calls.last.page, 1);
  });

  testWidgets('切换排序评分后 sort_by=score 且从第一页重新加载', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '系列 - Madonna',
          type: 2,
          category: 's',
          id: 's1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('common-list-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('评分').last);
    await tester.pumpAndSettle();

    expect(source.calls.last.sortBy, 'score');
    expect(source.calls.last.page, 1);
  });

  testWidgets('发布日期可切换方向，其他排序方向按钮不可用', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '系列 - Madonna',
          type: 2,
          category: 's',
          id: 's1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 默认热度：方向按钮不可用
    var toggle = tester.widget<IconButton>(
      find.byKey(const Key('common-list-order-toggle')),
    );
    expect(toggle.onPressed, isNull);

    // 切换到发布日期：方向按钮可用
    await tester.tap(find.byKey(const Key('common-list-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发布日期').last);
    await tester.pumpAndSettle();
    toggle = tester.widget<IconButton>(
      find.byKey(const Key('common-list-order-toggle')),
    );
    expect(toggle.onPressed, isNotNull);
    expect(source.calls.last.orderBy, 'desc');

    // 点击方向按钮切正序
    await tester.tap(find.byKey(const Key('common-list-order-toggle')));
    await tester.pumpAndSettle();
    expect(source.calls.last.orderBy, 'asc');
    expect(source.calls.last.sortBy, 'release');
  });

  testWidgets('清单创建时间方向按钮不可用', (tester) async {
    final source = _RecordingTagMoviesDataSource();
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '清单 - 收藏精选',
          type: 0,
          category: 'l',
          id: 'list-1',
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('common-list-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建时间').last);
    await tester.pumpAndSettle();

    final toggle = tester.widget<IconButton>(
      find.byKey(const Key('common-list-order-toggle')),
    );
    expect(toggle.onPressed, isNull);
    expect(source.calls.last.sortBy, 'release');
    expect(source.calls.last.orderBy, 'desc');
  });
}
