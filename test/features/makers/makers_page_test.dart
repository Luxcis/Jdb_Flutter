import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/makers/screens/makers_page.dart';
import 'package:jade/features/makers/services/maker_service.dart';

void main() {
  testWidgets('渲染 5 个 Tab，默认加载有码 type=0', (tester) async {
    final source = _RecordingMakerDataSource();
    await tester.pumpWidget(MaterialApp(home: MakersPage(dataSource: source)));
    await tester.pumpAndSettle();

    for (final tab in ['有码', '无码', '欧美', 'FC2', '动漫']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('Heydouga'), findsOneWidget);
    expect(find.text('(25645)'), findsOneWidget);
    expect(source.calls, [(type: 0, page: 1)]);
  });

  testWidgets('切换到无码 Tab 触发 getMakers(type=1)', (tester) async {
    final source = _RecordingMakerDataSource();
    await tester.pumpWidget(MaterialApp(home: MakersPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('无码'));
    await tester.pumpAndSettle();

    expect(source.calls, [(type: 0, page: 1), (type: 1, page: 1)]);
  });

  testWidgets('切回 Tab 保留列表状态，不重复请求', (tester) async {
    final source = _RecordingMakerDataSource();
    await tester.pumpWidget(MaterialApp(home: MakersPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('无码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('有码'));
    await tester.pumpAndSettle();

    expect(source.calls, [(type: 0, page: 1), (type: 1, page: 1)]);
  });

  testWidgets('点击片商条目进入与搜索结果一致的 CommonListPage', (tester) async {
    final source = _RecordingMakerDataSource();
    await tester.pumpWidget(MaterialApp(home: MakersPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Heydouga'));
    await tester.pumpAndSettle();

    final page = tester.widget<CommonListPage>(find.byType(CommonListPage));
    expect(page.title, '片商 - Heydouga');
    expect(page.type, 0);
    expect(page.category, 'm');
    expect(page.id, 'xZyO');
    expect(find.byKey(const Key('common-list-filter')), findsOneWidget);
    expect(find.byKey(const Key('common-list-sort')), findsOneWidget);
    expect(find.byType(MovieGridView), findsOneWidget);
  });
}

class _RecordingMakerDataSource implements MakerDataSource {
  final calls = <({int type, int page})>[];

  @override
  Future<PagedResult<Maker>> getMakers({
    required int type,
    int page = 1,
    int limit = 48,
  }) async {
    calls.add((type: type, page: page));
    return PagedResult(
      items: [
        Maker(id: 'xZyO', name: 'Heydouga', movieCount: 25645, type: type),
      ],
      currentPage: page,
      totalPages: page,
      total: 1,
    );
  }
}
