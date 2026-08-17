import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

void main() {
  testWidgets('点击影片卡片默认打开对应影片详情页', (tester) async {
    final movie = MovieSummary(
      id: 'movie-42',
      number: 'JDB-042',
      title: '默认导航影片',
      coverUrl: '',
    );
    final controller = PaginationController<MovieSummary>(
      fetch: (_) async =>
          PagedResult(items: [movie], currentPage: 1, totalPages: 1, total: 1),
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              Scaffold(body: MovieGridView(controller: controller)),
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (context, state) =>
              Scaffold(body: Text('详情 ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byType(MovieCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(router.state.uri.path, '/movie/movie-42');
    expect(find.text('详情 movie-42'), findsOneWidget);
  });

  testWidgets('空数据首次加载时显示居中进度环', (tester) async {
    final pending = Completer<PagedResult<MovieSummary>>();
    final controller = PaginationController<MovieSummary>(
      fetch: (_) => pending.future,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieGridView(controller: controller)),
      ),
    );

    controller.fetchMore();
    await tester.pump();

    expect(find.byKey(const Key('movie-grid-initial-loading')), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('已有数据加载下一页时保留影片并显示底部进度环', (tester) async {
    final nextPage = Completer<PagedResult<MovieSummary>>();
    final movie = MovieSummary(
      id: 'm1',
      number: 'ABC-001',
      title: '测试影片',
      coverUrl: 'cover.jpg',
    );
    final controller = PaginationController<MovieSummary>(
      fetch: (page) {
        if (page == 1) {
          return Future.value(
            PagedResult(
              items: [movie],
              currentPage: 1,
              totalPages: 2,
              total: 2,
            ),
          );
        }
        return nextPage.future;
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieGridView(controller: controller)),
      ),
    );

    controller.fetchMore();
    await tester.pump();

    expect(find.text('测试影片'), findsOneWidget);
    expect(find.byKey(const Key('movie-grid-loading-more')), findsOneWidget);
  });

  testWidgets('滚动接近底部 400px 时自动请求下一页', (tester) async {
    final requestedPages = <int>[];
    final movies = List.generate(
      30,
      (index) => MovieSummary(
        id: '$index',
        number: 'N-$index',
        title: '影片 $index',
        coverUrl: '',
      ),
    );
    final controller = PaginationController<MovieSummary>(
      fetch: (page) async {
        requestedPages.add(page);
        return PagedResult(
          items: page == 1 ? movies : const [],
          currentPage: page,
          totalPages: 2,
          total: 30,
        );
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieGridView(controller: controller)),
      ),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    await tester.drag(
      find.byType(CustomScrollView),
      Offset(0, -(scrollable.position.maxScrollExtent - 300)),
    );
    await tester.pump();

    expect(requestedPages, contains(2));
  });

  testWidgets('已有列表加载失败时可点击重试并追加下一页', (tester) async {
    var pageTwoAttempts = 0;
    final firstMovie = MovieSummary(
      id: 'm1',
      number: 'ABC-001',
      title: '第一页影片',
      coverUrl: '',
    );
    final secondMovie = MovieSummary(
      id: 'm2',
      number: 'ABC-002',
      title: '第二页影片',
      coverUrl: '',
    );
    final controller = PaginationController<MovieSummary>(
      fetch: (page) async {
        if (page == 1) {
          return PagedResult(
            items: [firstMovie],
            currentPage: 1,
            totalPages: 2,
            total: 2,
          );
        }
        if (pageTwoAttempts++ == 0) throw StateError('加载下一页失败');
        return PagedResult(
          items: [secondMovie],
          currentPage: 2,
          totalPages: 2,
          total: 2,
        );
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();
    await controller.fetchMore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieGridView(controller: controller)),
      ),
    );

    expect(find.text('第一页影片'), findsOneWidget);
    expect(find.byKey(const Key('movie-grid-load-more-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('movie-grid-load-more-retry')));
    await tester.pump();

    expect(find.text('第一页影片'), findsOneWidget);
    expect(find.text('第二页影片'), findsOneWidget);
    expect(find.byKey(const Key('movie-grid-load-more-retry')), findsNothing);
  });

  testWidgets('保留内容刷新时显示刷新条，完成后移除', (tester) async {
    final refreshedPage = Completer<PagedResult<MovieSummary>>();
    final movie = MovieSummary(
      id: 'm1',
      number: 'ABC-001',
      title: '测试影片',
      coverUrl: '',
    );
    final controller = PaginationController<MovieSummary>(
      fetch: (_) async =>
          PagedResult(items: [movie], currentPage: 1, totalPages: 1, total: 1),
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieGridView(controller: controller)),
      ),
    );

    final refresh = controller.reloadWith(
      (_) => refreshedPage.future,
      preserveItems: true,
    );
    await tester.pump();

    expect(find.byKey(const Key('movie-grid-refreshing')), findsOneWidget);

    refreshedPage.complete(
      PagedResult(items: [movie], currentPage: 1, totalPages: 1, total: 1),
    );
    await refresh;
    await tester.pump();

    expect(find.byKey(const Key('movie-grid-refreshing')), findsNothing);
  });

  testWidgets('空数据且非加载非错误时显示空态', (tester) async {
    final controller = PaginationController<MovieSummary>(
      fetch: (_) async =>
          PagedResult(items: const [], currentPage: 1, totalPages: 1, total: 0),
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieGridView(controller: controller)),
      ),
    );

    expect(find.text('暂无数据'), findsOneWidget);
    expect(find.byType(CustomScrollView), findsNothing);
  });
}
