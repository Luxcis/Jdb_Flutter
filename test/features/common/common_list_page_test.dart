import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/features/common/screens/common_list_page.dart';

void main() {
  testWidgets('显示标题筛选排序和影片网格且筛选只刷新本地数据源', (tester) async {
    var fetchCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CommonListPage(
          title: '系列 - Madonna',
          dataSource: (page) async {
            fetchCount++;
            return PagedResult(
              items: const [],
              currentPage: page,
              totalPages: page,
              total: 0,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('系列 - Madonna'), findsOneWidget);
    for (final label in ['全部', '可播放', '含磁链', '字幕']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('最新'), findsOneWidget);
    expect(find.byKey(const Key('common-list-filter')), findsOneWidget);
    expect(find.byKey(const Key('common-list-sort')), findsOneWidget);
    expect(find.byType(MovieGridView), findsOneWidget);
    expect(fetchCount, 1);

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SortSegmented<String>>(
            find.byKey(const Key('common-list-filter')),
          )
          .value,
      'all',
    );
    expect(fetchCount, 2);

    await tester.tap(find.byKey(const Key('common-list-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('热门').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SortSelect<String>>(find.byKey(const Key('common-list-sort')))
          .value,
      'hot',
    );
    expect(fetchCount, 3);
  });
}
