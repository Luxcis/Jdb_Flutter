import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';

void main() {
  testWidgets('显示加粗名称影片数查看数箭头并触发点击', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListSummaryTile(
            list: const ListModel(
              id: 'l1',
              name: '收藏精选',
              movieCount: 12,
              viewedCount: 34,
            ),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('收藏精选'), findsOneWidget);
    expect(find.text('12 部影片，被查看 34 次'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('收藏精选')).style?.fontWeight,
      FontWeight.w600,
    );
    await tester.tap(find.byType(ListSummaryTile));
    expect(tapped, isTrue);
  });

  testWidgets('未提供 onTap 时默认跳转 common-list', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: ListSummaryTile(
              list: ListModel(
                id: 'l1',
                name: '收藏精选',
                movieCount: 12,
                viewedCount: 34,
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.commonList,
          builder: (_, state) => Scaffold(
            body: Text('common-list ${state.uri.queryParameters}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byType(ListSummaryTile));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.commonList);
    expect(router.state.uri.queryParameters, {
      'title': '清单 - 收藏精选',
      'type': '0',
      'category': 'l',
      'id': 'l1',
    });
  });

  testWidgets('showViewCount 为 false 时副标题不显示被查看次数', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListSummaryTile(
            list: ListModel(
              id: 'l1',
              name: '收藏精选',
              movieCount: 12,
              viewedCount: 34,
            ),
            showViewCount: false,
          ),
        ),
      ),
    );

    expect(find.text('12 部影片'), findsOneWidget);
    expect(find.text('12 部影片，被查看 34 次'), findsNothing);
    expect(find.textContaining('被查看'), findsNothing);
  });
}
