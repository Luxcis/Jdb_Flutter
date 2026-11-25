import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

void main() {
  testWidgets('首屏无内容加载时显示居中进度', (tester) async {
    final firstPage = Completer<PagedResult<ActorSummary>>();
    final controller = PaginationController<ActorSummary>(
      fetch: (_) => firstPage.future,
    );
    addTearDown(controller.dispose);
    final fetch = controller.fetchMore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActorGridView(controller: controller)),
      ),
    );

    expect(find.byKey(const Key('actor-grid-initial-loading')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const Key('actor-grid-initial-loading')),
        matching: find.byType(Center),
      ),
      findsOneWidget,
    );

    firstPage.complete(
      const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
    );
    await fetch;
  });

  testWidgets('320px 暗色大字体下演员网格不溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = PaginationController<ActorSummary>(
      fetch: (_) async => const PagedResult(
        items: [ActorSummary(id: 'a1', name: '很长很长的演员名称', avatarUrl: '')],
        currentPage: 1,
        totalPages: 1,
        total: 1,
      ),
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: ActorGridView(controller: controller)),
      ),
    );

    expect(find.text('很长很长的演员名称'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('滚动接近底部自动加载下一页', (tester) async {
    final requestedPages = <int>[];
    final controller = PaginationController<ActorSummary>(
      fetch: (page) async {
        requestedPages.add(page);
        return PagedResult(
          items: List.generate(
            60,
            (index) => ActorSummary(
              id: '$page-$index',
              name: '演员 $page-$index',
              avatarUrl: '',
            ),
          ),
          currentPage: page,
          totalPages: page + 1,
          total: 120,
        );
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActorGridView(controller: controller)),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GridView)),
    );
    await gesture.moveBy(const Offset(0, -4000));
    await tester.pump();
    await tester.pump();

    expect(requestedPages, [1, 2]);
    await gesture.up();
  });

  testWidgets('下一页加载时显示紧凑页尾进度', (tester) async {
    final secondPage = Completer<PagedResult<ActorSummary>>();
    final controller = PaginationController<ActorSummary>(
      fetch: (page) async {
        if (page == 2) return secondPage.future;
        return PagedResult(
          items: List.generate(
            3,
            (index) => ActorSummary(
              id: '$page-$index',
              name: '演员 $page-$index',
              avatarUrl: '',
            ),
          ),
          currentPage: page,
          totalPages: 2,
          total: 4,
        );
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();
    final fetch = controller.fetchMore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActorGridView(controller: controller)),
      ),
    );

    expect(find.byKey(const Key('actor-grid-tail-loading')), findsOneWidget);

    secondPage.complete(
      const PagedResult(
        items: [ActorSummary(id: '2-0', name: '演员 2-0', avatarUrl: '')],
        currentPage: 2,
        totalPages: 2,
        total: 4,
      ),
    );
    await fetch;
  });

  testWidgets('保留内容刷新时显示顶部进度而非页尾进度', (tester) async {
    var requestCount = 0;
    final refreshedPage = Completer<PagedResult<ActorSummary>>();
    final controller = PaginationController<ActorSummary>(
      fetch: (_) {
        requestCount++;
        if (requestCount == 1) {
          return Future.value(
            const PagedResult(
              items: [ActorSummary(id: 'old', name: '原演员', avatarUrl: '')],
              currentPage: 1,
              totalPages: 1,
              total: 1,
            ),
          );
        }
        return refreshedPage.future;
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActorGridView(controller: controller)),
      ),
    );

    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();

    expect(find.text('原演员'), findsOneWidget);
    expect(find.byKey(const Key('actor-grid-refreshing')), findsOneWidget);
    expect(find.byKey(const Key('actor-grid-tail-loading')), findsNothing);

    refreshedPage.complete(
      const PagedResult(
        items: [ActorSummary(id: 'new', name: '新演员', avatarUrl: '')],
        currentPage: 1,
        totalPages: 1,
        total: 1,
      ),
    );
    await refresh;
    await tester.pump();

    expect(find.text('原演员'), findsNothing);
    expect(find.text('新演员'), findsOneWidget);
    expect(find.byKey(const Key('actor-grid-refreshing')), findsNothing);
  });

  testWidgets('下拉刷新失败保留旧演员并允许重试', (tester) async {
    var requestCount = 0;
    final controller = PaginationController<ActorSummary>(
      fetch: (_) async {
        requestCount++;
        if (requestCount == 1) {
          return const PagedResult(
            items: [ActorSummary(id: 'old', name: '原演员', avatarUrl: '')],
            currentPage: 1,
            totalPages: 1,
            total: 1,
          );
        }
        if (requestCount == 2) throw StateError('刷新失败');
        return const PagedResult(
          items: [ActorSummary(id: 'new', name: '重试演员', avatarUrl: '')],
          currentPage: 1,
          totalPages: 1,
          total: 1,
        );
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActorGridView(controller: controller)),
      ),
    );

    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();

    expect(find.text('原演员'), findsOneWidget);
    expect(find.byKey(const Key('actor-grid-tail-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('actor-grid-tail-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.text('原演员'), findsNothing);
    expect(find.text('重试演员'), findsOneWidget);
    expect(find.byKey(const Key('actor-grid-tail-retry')), findsNothing);
  });

  testWidgets('下一页失败时保留演员并显示可重试页尾', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 4000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    var attempts = 0;
    final controller = PaginationController<ActorSummary>(
      fetch: (page) async {
        if (page == 2 && attempts++ == 0) {
          throw StateError('下一页失败');
        }
        return PagedResult(
          items: List.generate(
            page == 1 ? 60 : 1,
            (index) => ActorSummary(
              id: '$page-$index',
              name: '演员 $page-$index',
              avatarUrl: '',
            ),
          ),
          currentPage: page,
          totalPages: 2,
          total: 61,
        );
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();
    await controller.fetchMore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActorGridView(controller: controller)),
      ),
    );

    expect(find.text('演员 1-0'), findsOneWidget);
    expect(find.byKey(const Key('actor-grid-tail-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('actor-grid-tail-retry')));
    await tester.pump();
    await tester.pump();
    expect(controller.items.length, 61);
  });

  testWidgets('加载更多失败后继续滚动不再自动请求，点击重试才重发', (tester) async {
    final requestedPages = <int>[];
    final controller = PaginationController<ActorSummary>(
      fetch: (page) async {
        requestedPages.add(page);
        if (page == 1) {
          return PagedResult(
            items: List.generate(
              60,
              (index) => ActorSummary(
                id: '1-$index',
                name: '演员 1-$index',
                avatarUrl: '',
              ),
            ),
            currentPage: 1,
            totalPages: 2,
            total: 61,
          );
        }
        throw StateError('page 2 failed');
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActorGridView(controller: controller)),
      ),
    );

    final grid = find.byType(GridView);
    await tester.drag(grid, const Offset(0, -5000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(requestedPages, [1, 2]);

    // 滚到列表底部让重试按钮进入视口。
    await tester.drag(grid, const Offset(0, -600));
    await tester.pump();
    expect(find.byKey(const Key('actor-grid-tail-retry')), findsOneWidget);

    // 失败后继续滚动（含惯性滚动逐帧通知）不得自动重发请求。
    for (var i = 0; i < 3; i++) {
      await tester.drag(grid, const Offset(0, -400));
      await tester.pump();
    }
    expect(requestedPages, [1, 2]);
    expect(find.byKey(const Key('actor-grid-tail-loading')), findsNothing);
    expect(find.byKey(const Key('actor-grid-tail-retry')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('actor-grid-tail-retry')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('actor-grid-tail-retry')));
    await tester.pump();
    expect(requestedPages, [1, 2, 2]);
  });

  testWidgets('首屏加载失败显示统一中文文案而非原始异常', (tester) async {
    final controller = PaginationController<ActorSummary>(
      fetch: (_) async => throw StateError('network down'),
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActorGridView(controller: controller)),
      ),
    );

    expect(find.text('加载失败，请重试'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
  });
}
