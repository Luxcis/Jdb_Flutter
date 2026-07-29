import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';
import 'package:jade/features/categories/services/category_service.dart';
import 'package:jade/features/categories/services/category_tab_controller.dart';
import 'package:jade/features/categories/widgets/category_filter_sheet.dart';

class _MovieFilterRequest {
  const _MovieFilterRequest({
    required this.filterBy,
    required this.sort,
    required this.orderBy,
  });

  final String filterBy;
  final CategorySort sort;
  final String orderBy;
}

class _FakeSource implements CategoryDataSource {
  final movieRequests = <_MovieFilterRequest>[];
  Completer<List<CategoryTagGroup>>? pendingTags;
  List<CategoryTagGroup> tagsResult = _groups;
  var tagFailuresRemaining = 0;

  List<String> get movieFilters =>
      movieRequests.map((request) => request.filterBy).toList(growable: false);

  @override
  Future<List<CategoryTagGroup>> getTags({required int type}) async {
    if (tagFailuresRemaining > 0) {
      tagFailuresRemaining--;
      throw StateError('标签加载失败');
    }
    final pending = pendingTags;
    if (pending != null) return pending.future;
    return tagsResult;
  }

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required int type,
    required CategoryFilter filter,
    required List<String> categoryOrder,
    int page = 1,
  }) async {
    movieRequests.add(
      _MovieFilterRequest(
        filterBy: filter.toFilterBy(type, categoryOrder),
        sort: filter.sort,
        orderBy: filter.orderBy,
      ),
    );
    return const PagedResult(
      items: [],
      currentPage: 1,
      totalPages: 1,
      total: 0,
    );
  }
}

const _groups = <CategoryTagGroup>[
  CategoryTagGroup(
    category: '基本',
    categoryId: 'main',
    tags: [
      CategoryTagItem(id: 'p', name: '可播放', videosCount: 1),
      CategoryTagItem(id: 'm', name: '有磁链', videosCount: 1),
    ],
  ),
  CategoryTagGroup(
    category: '题材',
    categoryId: 'subject',
    tags: [
      CategoryTagItem(id: '23', name: '剧情', videosCount: 1),
      CategoryTagItem(id: '51', name: '喜剧', videosCount: 1),
    ],
  ),
  CategoryTagGroup(
    category: '年份',
    categoryId: 'year',
    tags: [
      CategoryTagItem(id: '2025', name: '2025', videosCount: 1),
      CategoryTagItem(id: '2024', name: '2024', videosCount: 1),
    ],
  ),
  CategoryTagGroup(
    category: '时长',
    categoryId: 'duration',
    tags: [
      CategoryTagItem(id: '60', name: '60 分钟内', videosCount: 1),
      CategoryTagItem(id: '120', name: '120 分钟内', videosCount: 1),
    ],
  ),
  CategoryTagGroup(
    category: '月份',
    categoryId: 'month',
    tags: [
      CategoryTagItem(id: '01', name: '一月', videosCount: 1),
      CategoryTagItem(id: '02', name: '二月', videosCount: 1),
    ],
  ),
];

Widget _sheet(CategoryTabController controller) => MaterialApp(
  home: Scaffold(body: CategoryFilterSheet(controller: controller)),
);

String _filterBy(CategoryTabController controller) =>
    controller.filter.toFilterBy(
      controller.type,
      controller.groups.map((group) => group.categoryId).toList(),
    );

void main() {
  testWidgets('动态标签以紧凑 Chip 渲染且点击立即更新筛选', (tester) async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    expect(find.text('基本'), findsOneWidget);
    expect(find.text('题材'), findsOneWidget);
    expect(find.text('可播放'), findsOneWidget);
    expect(find.text('剧情'), findsOneWidget);
    expect(find.text('客户端固定分组'), findsNothing);

    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
      expect(chip.visualDensity, VisualDensity.compact);
      expect(chip.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(chip.showCheckmark, isFalse);
    }

    await tester.tap(find.byKey(const Key('category-filter-main-p')));
    await tester.pump();

    expect(source.movieFilters.last, '0:t:p::::');
    expect(find.text('筛选'), findsOneWidget);
  });

  testWidgets('固定段单选而动态题材保持多选', (tester) async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    await tester.tap(find.byKey(const Key('category-filter-main-p')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-filter-main-m')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-filter-subject-23')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-filter-subject-51')));
    await tester.pump();

    expect(source.movieFilters.last, '0:t:m:23,51:::');
    expect(
      tester
          .widget<FilterChip>(find.byKey(const Key('category-filter-main-p')))
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<FilterChip>(find.byKey(const Key('category-filter-main-m')))
          .selected,
      isTrue,
    );
  });

  testWidgets('标签请求在途显示加载状态，完成后显示动态分组', (tester) async {
    final source = _FakeSource()
      ..pendingTags = Completer<List<CategoryTagGroup>>();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);

    final initialization = controller.initialize();
    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('category-filter-list')), findsNothing);

    source.pendingTags!.complete(_groups);
    await initialization;
    await tester.pump();

    expect(find.byKey(const Key('category-filter-group-main')), findsOneWidget);
  });

  testWidgets('标签失败显示重试，重试成功后恢复动态分组', (tester) async {
    final source = _FakeSource()..tagFailuresRemaining = 1;
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);

    final initialization = controller.initialize();
    await tester.pumpWidget(_sheet(controller));
    await tester.pump();
    await initialization;
    await tester.pump();

    final retry = find.text('筛选内容加载失败，点击重试');
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-filter-group-main')), findsOneWidget);
    expect(find.text('可播放'), findsOneWidget);
  });

  testWidgets('成功空标签列表显示明确空状态', (tester) async {
    final source = _FakeSource()..tagsResult = const [];
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    expect(find.byKey(const Key('category-filter-empty')), findsOneWidget);
    expect(find.text('暂无筛选项'), findsOneWidget);
    expect(find.byKey(const Key('category-filter-list')), findsNothing);
  });

  testWidgets('year duration month 由模型保持单选和取消语义', (tester) async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    final year2025 = find.byKey(const Key('category-filter-year-2025'));
    final year2024 = find.byKey(const Key('category-filter-year-2024'));
    await tester.tap(year2025);
    await tester.pump();
    expect(tester.widget<FilterChip>(year2025).selected, isTrue);
    expect(_filterBy(controller), '0:t:::2025::');
    await tester.tap(year2024);
    await tester.pump();
    expect(tester.widget<FilterChip>(year2025).selected, isFalse);
    expect(tester.widget<FilterChip>(year2024).selected, isTrue);
    expect(_filterBy(controller), '0:t:::2024::');
    await tester.tap(year2024);
    await tester.pump();
    expect(tester.widget<FilterChip>(year2024).selected, isFalse);
    expect(_filterBy(controller), '0:t:::::');

    final list = find.byKey(const Key('category-filter-list'));
    final duration60 = find.byKey(const Key('category-filter-duration-60'));
    final duration120 = find.byKey(const Key('category-filter-duration-120'));
    await tester.scrollUntilVisible(
      duration60,
      250,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    await tester.tap(duration60);
    await tester.pump();
    expect(tester.widget<FilterChip>(duration60).selected, isTrue);
    expect(_filterBy(controller), '0:t::::60:');
    await tester.tap(duration120);
    await tester.pump();
    expect(tester.widget<FilterChip>(duration60).selected, isFalse);
    expect(tester.widget<FilterChip>(duration120).selected, isTrue);
    expect(_filterBy(controller), '0:t::::120:');
    await tester.tap(duration120);
    await tester.pump();
    expect(tester.widget<FilterChip>(duration120).selected, isFalse);
    expect(_filterBy(controller), '0:t:::::');

    final month01 = find.byKey(const Key('category-filter-month-01'));
    final month02 = find.byKey(const Key('category-filter-month-02'));
    await tester.scrollUntilVisible(
      month01,
      250,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    await tester.tap(month01);
    await tester.pump();
    expect(tester.widget<FilterChip>(month01).selected, isTrue);
    expect(_filterBy(controller), '0:t:::::01');
    await tester.tap(month02);
    await tester.pump();
    expect(tester.widget<FilterChip>(month01).selected, isFalse);
    expect(tester.widget<FilterChip>(month02).selected, isTrue);
    expect(_filterBy(controller), '0:t:::::02');
    await tester.tap(month02);
    await tester.pump();
    expect(tester.widget<FilterChip>(month02).selected, isFalse);
    expect(_filterBy(controller), '0:t:::::');
  });

  testWidgets('排序菜单和发布日期升降序可即时触达', (tester) async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_sheet(controller));
    await tester.pump();

    await tester.tap(find.byKey(const Key('category-order-toggle')));
    await tester.pump();

    expect(controller.filter.orderBy, 'asc');
    expect(source.movieRequests.last.orderBy, 'asc');

    await tester.tap(find.byKey(const Key('category-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('评分').last);
    await tester.pump();

    expect(controller.filter.sort, CategorySort.score);
    expect(source.movieRequests.last.sort, CategorySort.score);
    expect(find.byKey(const Key('category-order-toggle')), findsNothing);

    await tester.tap(find.byKey(const Key('category-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发布日期').last);
    await tester.pump();

    expect(find.byKey(const Key('category-order-toggle')), findsOneWidget);
  });

  testWidgets('窄屏大字体下动态长列表可滚动且不溢出', (tester) async {
    final source = _FakeSource();
    final controller = CategoryTabController(type: 0, source: source);
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: _sheet(controller),
      ),
    );
    await tester.pump();

    final list = find.byKey(const Key('category-filter-list'));
    final monthChip = find.byKey(const Key('category-filter-month-01'));
    expect(list, findsOneWidget);
    await tester.scrollUntilVisible(
      monthChip,
      250,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(monthChip, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
