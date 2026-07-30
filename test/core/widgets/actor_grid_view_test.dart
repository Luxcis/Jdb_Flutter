import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

void main() {
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
}
