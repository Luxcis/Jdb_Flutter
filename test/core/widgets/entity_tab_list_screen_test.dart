import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/entity_tab_list_screen.dart';

void main() {
  testWidgets('渲染标题与全部 Tab，默认加载第一个 Tab 第一页', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _app(
        tabs: [
          _tab('有码', calls, items: const [1, 2]),
          _tab('无码', calls, items: const [3]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试实体'), findsOneWidget);
    expect(find.text('有码'), findsOneWidget);
    expect(find.text('无码'), findsOneWidget);
    expect(find.text('条目-1'), findsOneWidget);
    expect(find.text('条目-2'), findsOneWidget);
    expect(calls, ['有码:1']);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final tabBarView = tester.widget<TabBarView>(find.byType(TabBarView));
    expect(tabBar.tabs.length, 2);
    expect(tabBarView.children.length, 2);
  });

  testWidgets('加载中显示进度指示器，完成后显示条目', (tester) async {
    final gate = Completer<void>();
    final calls = <String>[];
    await tester.pumpWidget(
      _app(
        tabs: [
          _tab('有码', calls, items: const [1], gate: gate),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('条目-1'), findsOneWidget);
  });

  testWidgets('空结果显示 Tab 级空态文案，未配置时用页面默认文案', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _app(
        tabs: [
          _tab('番号', calls, items: const [], emptyMessage: '暂无番号'),
          _tab('系列', calls, items: const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无番号'), findsOneWidget);

    await tester.tap(find.text('系列'));
    await tester.pumpAndSettle();

    expect(find.text('暂无数据'), findsOneWidget);
  });

  testWidgets('错误态显示错误信息，重试后重新请求并显示条目', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _app(
        tabs: [
          EntityTabSpec<int>(
            label: '有码',
            fetch: (page) async {
              attempts++;
              if (attempts == 1) throw StateError('boom');
              return _page(const [7], page: page);
            },
            tile: _tile,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 列表错误文案统一经 userFacingErrorMessage 转成中文，不暴露原始异常文本。
    expect(find.text('加载失败，请重试'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('条目-7'), findsOneWidget);
  });

  testWidgets('滚动到底部自动加载下一页', (tester) async {
    final calls = <int>[];
    await tester.pumpWidget(
      _app(
        tabs: [
          EntityTabSpec<int>(
            label: '有码',
            fetch: (page) async {
              calls.add(page);
              return _page(
                page == 1
                    ? List<int>.generate(20, (index) => index + 1)
                    : const [21],
                page: page,
                totalPages: 2,
              );
            },
            tile: _tile,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(calls, [1, 2]);
    expect(find.text('条目-21', skipOffstage: false), findsOneWidget);
  });

  testWidgets('切换 Tab 后返回，列表保活且不重复请求', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _app(
        tabs: [
          _tab('有码', calls, items: const [1]),
          _tab('无码', calls, items: const [2]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('无码'));
    await tester.pumpAndSettle();
    expect(calls, ['有码:1', '无码:1']);

    await tester.tap(find.text('有码'));
    await tester.pumpAndSettle();

    expect(calls, ['有码:1', '无码:1']);
    expect(find.text('条目-1'), findsOneWidget);
  });
}

Widget _app({required List<EntityTabSpec<int>> tabs}) => MaterialApp(
  home: EntityTabListScreen<int>(
    title: '测试实体',
    emptyMessage: '暂无数据',
    tabs: tabs,
  ),
);

EntityTabSpec<int> _tab(
  String label,
  List<String> calls, {
  required List<int> items,
  int totalPages = 1,
  String? emptyMessage,
  Completer<void>? gate,
}) => EntityTabSpec<int>(
  label: label,
  emptyMessage: emptyMessage,
  fetch: (page) async {
    calls.add('$label:$page');
    if (gate != null) await gate.future;
    return _page(items, page: page, totalPages: totalPages);
  },
  tile: _tile,
);

Widget _tile(BuildContext context, int item) =>
    ListTile(title: Text('条目-$item'));

PagedResult<int> _page(
  List<int> items, {
  required int page,
  int totalPages = 1,
}) => PagedResult<int>(
  items: items,
  currentPage: page,
  totalPages: totalPages,
  total: items.length,
);
