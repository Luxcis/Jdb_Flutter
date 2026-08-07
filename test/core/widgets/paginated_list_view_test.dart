import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';

Future<void> _pumpList(
  WidgetTester tester,
  PaginationController<_Item> controller,
) => tester.pumpWidget(
  MaterialApp(
    home: PaginatedListView<_Item>(
      controller: controller,
      emptyMessage: '暂无结果',
      itemBuilder: (_, item) => Text(item.id),
    ),
  ),
);

void main() {
  testWidgets('接近底部自动加载并在追加失败时保留内容显示重试', (tester) async {
    final controller = PaginationController<_Item>(
      fetch: (page) async {
        if (page == 1) {
          return PagedResult(
            items: List.generate(30, (i) => _Item('$i')),
            currentPage: 1,
            totalPages: 2,
            total: 31,
          );
        }
        throw StateError('page 2 failed');
      },
    )..fetchMore();
    addTearDown(controller.dispose);

    await _pumpList(tester, controller);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();

    expect(find.text('29'), findsOneWidget);
    expect(find.byKey(const Key('search-list-tail-retry')), findsOneWidget);
  });

  testWidgets('首屏加载完成后显示空状态', (tester) async {
    final completer = Completer<PagedResult<_Item>>();
    final controller = PaginationController<_Item>(
      fetch: (_) => completer.future,
    )..fetchMore();
    addTearDown(controller.dispose);

    await _pumpList(tester, controller);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(
      const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无结果'), findsOneWidget);
  });

  testWidgets('首屏错误点击重试后恢复空状态', (tester) async {
    var attempts = 0;
    final controller = PaginationController<_Item>(
      fetch: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('first failed');
        return const PagedResult(
          items: [],
          currentPage: 1,
          totalPages: 1,
          total: 0,
        );
      },
    )..fetchMore();
    addTearDown(controller.dispose);

    await _pumpList(tester, controller);
    await tester.pumpAndSettle();
    expect(find.byType(ErrorRetryWidget), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('暂无结果'), findsOneWidget);
  });

  testWidgets('追加加载保留现有内容并显示尾部进度', (tester) async {
    final secondPage = Completer<PagedResult<_Item>>();
    final controller = PaginationController<_Item>(
      fetch: (page) async {
        if (page == 1) {
          return const PagedResult(
            items: [_Item('1')],
            currentPage: 1,
            totalPages: 2,
            total: 2,
          );
        }
        return secondPage.future;
      },
    )..fetchMore();
    addTearDown(controller.dispose);

    await _pumpList(tester, controller);
    await tester.pumpAndSettle();
    controller.fetchMore();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    secondPage.complete(
      const PagedResult(
        items: [_Item('2')],
        currentPage: 2,
        totalPages: 2,
        total: 2,
      ),
    );
    await tester.pumpAndSettle();
  });
}

class _Item {
  const _Item(this.id);

  final String id;
}
