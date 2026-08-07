import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/directors/screens/directors_page.dart';
import 'package:jade/features/directors/services/director_service.dart';

void main() {
  testWidgets('渲染 2 个 Tab，默认加载有码 type=0', (tester) async {
    final source = _RecordingDirectorDataSource();
    await tester.pumpWidget(MaterialApp(home: DirectorsPage(dataSource: source)));
    await tester.pumpAndSettle();

    for (final tab in ['有码', '欧美']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('K太郎'), findsOneWidget);
    expect(find.text('(3122)'), findsOneWidget);
    expect(source.calls, [(type: 0, page: 1)]);
  });

  testWidgets('切换到欧美 Tab 触发 getDirectors(type=2)', (tester) async {
    final source = _RecordingDirectorDataSource();
    await tester.pumpWidget(MaterialApp(home: DirectorsPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('欧美'));
    await tester.pumpAndSettle();

    expect(source.calls, [(type: 0, page: 1), (type: 2, page: 1)]);
  });

  testWidgets('切回 Tab 保留列表状态，不重复请求', (tester) async {
    final source = _RecordingDirectorDataSource();
    await tester.pumpWidget(MaterialApp(home: DirectorsPage(dataSource: source)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('欧美'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('有码'));
    await tester.pumpAndSettle();

    expect(source.calls, [(type: 0, page: 1), (type: 2, page: 1)]);
  });

  testWidgets('点击导演条目经 /common-list 路由进入 CommonListPage', (tester) async {
    final source = _RecordingDirectorDataSource();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => DirectorsPage(dataSource: source)),
        GoRoute(
          path: AppRoutes.commonList,
          builder: (c, s) {
            final q = s.uri.queryParameters;
            return CommonListPage(
              title: q['title'] ?? '',
              type: int.tryParse(q['type'] ?? '') ?? 0,
              category: q['category'] ?? '',
              id: q['id'] ?? '',
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('K太郎'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters, {
      'title': '导演 - K太郎',
      'type': '0',
      'category': 'd',
      'id': 'AqK',
    });
    expect(find.byType(CommonListPage), findsOneWidget);
    expect(find.byKey(const Key('common-list-filter')), findsOneWidget);
    expect(find.byKey(const Key('common-list-sort')), findsOneWidget);
  });
}

class _RecordingDirectorDataSource implements DirectorDataSource {
  final calls = <({int type, int page})>[];

  @override
  Future<PagedResult<Director>> getDirectors({
    required int type,
    int page = 1,
    int limit = 48,
  }) async {
    calls.add((type: type, page: page));
    return PagedResult(
      items: [
        Director(id: 'AqK', name: 'K太郎', movieCount: 3122, type: type),
      ],
      currentPage: page,
      totalPages: page,
      total: 1,
    );
  }
}
