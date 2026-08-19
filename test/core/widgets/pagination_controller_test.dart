import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

PagedResult<int> _page(List<int> items) => PagedResult(
  items: items,
  currentPage: 1,
  totalPages: 1,
  total: items.length,
);

void main() {
  test('fetchMore 捕获数据源异常并暴露 error，不向外抛出', () async {
    final controller = PaginationController<int>(
      fetch: (_) => throw StateError('bad page'),
    );

    await controller.fetchMore();

    expect(controller.error.toString(), contains('bad page'));
    expect(controller.isLoading, isFalse);
  });

  test('reloadWith 只接受最后一次查询结果', () async {
    final first = Completer<PagedResult<int>>();
    final second = Completer<PagedResult<int>>();
    final controller = PaginationController<int>(fetch: (_) => first.future);

    final firstLoad = controller.fetchMore();
    final secondLoad = controller.reloadWith((_) => second.future);
    second.complete(_page([2]));
    await secondLoad;
    first.complete(_page([1]));
    await firstLoad;

    expect(controller.items, [2]);
    expect(controller.isLoading, isFalse);
  });

  test('preserveItems 刷新在成功前保留旧内容并在成功后替换', () async {
    final next = Completer<PagedResult<int>>();
    final controller = PaginationController<int>(
      fetch: (_) async => _page([1]),
    );
    await controller.fetchMore();

    final refresh = controller.reloadWith(
      (_) => next.future,
      preserveItems: true,
    );

    expect(controller.items, [1]);
    expect(controller.isRefreshing, isTrue);
    next.complete(_page([2]));
    await refresh;
    expect(controller.items, [2]);
    expect(controller.isRefreshing, isFalse);
  });

  test('preserveItems 刷新失败保留旧内容并允许重试后替换', () async {
    var refreshAttempts = 0;
    final controller = PaginationController<int>(
      fetch: (_) async => _page([1]),
    );
    await controller.fetchMore();

    await controller.reloadWith((_) async {
      if (refreshAttempts++ == 0) throw StateError('刷新失败');
      return _page([2]);
    }, preserveItems: true);

    expect(controller.items, [1]);
    expect(controller.error, isA<StateError>());
    expect(controller.isRefreshing, isFalse);

    await controller.fetchMore();

    expect(controller.items, [2]);
    expect(controller.error, isNull);
    expect(controller.isRefreshing, isFalse);
  });

  test('refresh 可保留旧内容，失败后仍能重试替换', () async {
    var requestCount = 0;
    final pendingRefresh = Completer<PagedResult<int>>();
    final controller = PaginationController<int>(
      fetch: (_) {
        requestCount++;
        if (requestCount == 1) return Future.value(_page([1]));
        if (requestCount == 2) return pendingRefresh.future;
        return Future.value(_page([2]));
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();

    final refresh = controller.refresh(preserveItems: true);

    expect(controller.items, [1]);
    expect(controller.isRefreshing, isTrue);

    pendingRefresh.completeError(StateError('刷新失败'));
    await refresh;

    expect(controller.items, [1]);
    expect(controller.error, isA<StateError>());
    expect(controller.isRefreshing, isFalse);

    await controller.fetchMore();

    expect(controller.items, [2]);
    expect(controller.error, isNull);
  });

  test('连续多次 refresh 都保留旧内容并整体替换', () async {
    var requestCount = 0;
    final controller = PaginationController<int>(
      fetch: (_) async {
        requestCount++;
        if (requestCount == 1) return _page([1]);
        if (requestCount == 2) return _page([2]);
        return _page([3]);
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();

    await controller.refresh();
    expect(controller.items, [2]);
    expect(controller.isRefreshing, isFalse);

    await controller.refresh();
    expect(controller.items, [3]);
    expect(controller.isRefreshing, isFalse);
  });

  test('refresh 默认保留旧内容，成功后整体替换', () async {
    var requestCount = 0;
    final pending = Completer<PagedResult<int>>();
    final controller = PaginationController<int>(
      fetch: (_) {
        requestCount++;
        if (requestCount == 1) return Future.value(_page([1]));
        return pending.future;
      },
    );
    addTearDown(controller.dispose);
    await controller.fetchMore();

    final refresh = controller.refresh();
    expect(controller.items, [1]);
    expect(controller.isRefreshing, isTrue);

    pending.complete(_page([2]));
    await refresh;
    expect(controller.items, [2]);
    expect(controller.error, isNull);
    expect(controller.isRefreshing, isFalse);
  });
}
