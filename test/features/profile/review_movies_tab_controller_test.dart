import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/profile/services/review_movies_service.dart';
import 'package:jade/features/profile/services/review_movies_tab_controller.dart';

typedef _Request = ({
  String status,
  String type,
  String sortBy,
  String orderBy,
  int page,
});

class _RecordingSource implements ReviewMoviesDataSource {
  final requests = <_Request>[];
  Completer<PagedResult<MovieSummary>>? pending;

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String status,
    required String type,
    required String sortBy,
    required String orderBy,
    int page = 1,
  }) {
    requests.add((
      status: status,
      type: type,
      sortBy: sortBy,
      orderBy: orderBy,
      page: page,
    ));
    final currentPending = pending;
    if (currentPending != null) return currentPending.future;
    return Future.value(
      PagedResult(
        items: [
          MovieSummary(
            id: '$type-$page',
            number: 'N-$type-$page',
            title: '影片 $type-$page',
            coverUrl: '',
          ),
        ],
        currentPage: page,
        totalPages: page,
        total: 1,
      ),
    );
  }
}

void main() {
  test('initialize 只触发一次当前类型首屏请求', () async {
    final source = _RecordingSource();
    final controller = ReviewMoviesTabController(
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
      source: source,
    );
    addTearDown(controller.dispose);

    await Future.wait([controller.initialize(), controller.initialize()]);

    expect(source.requests, [
      (
        status: 'want_watch',
        type: 'all',
        sortBy: 'create',
        orderBy: 'desc',
        page: 1,
      ),
    ]);
  });

  test('未初始化 Tab 仅更新排序 首次访问才请求', () async {
    final source = _RecordingSource();
    final controller = ReviewMoviesTabController(
      status: 'want_watch',
      type: '1',
      sortBy: 'create',
      orderBy: 'desc',
      source: source,
    );
    addTearDown(controller.dispose);

    await controller.changeSorting(sortBy: 'release', orderBy: 'asc');
    expect(source.requests, isEmpty);

    await controller.initialize();
    expect(source.requests.single.sortBy, 'release');
    expect(source.requests.single.orderBy, 'asc');
  });

  test('已初始化 Tab 排序变化时保留旧影片并从第一页替换', () async {
    final source = _RecordingSource();
    final controller = ReviewMoviesTabController(
      status: 'want_watch',
      type: '0',
      sortBy: 'create',
      orderBy: 'desc',
      source: source,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final oldMovie = controller.movies.items.single;

    source.pending = Completer<PagedResult<MovieSummary>>();
    final refresh = controller.changeSorting(
      sortBy: 'release',
      orderBy: 'desc',
    );

    expect(controller.movies.items.single, same(oldMovie));
    expect(controller.movies.isRefreshing, isTrue);
    expect(source.requests.last.page, 1);
    source.pending!.complete(
      const PagedResult(
        items: [
          MovieSummary(
            id: 'new',
            number: 'NEW-1',
            title: '新排序影片',
            coverUrl: '',
          ),
        ],
        currentPage: 1,
        totalPages: 1,
        total: 1,
      ),
    );
    await refresh;

    expect(controller.movies.items.single.id, 'new');
  });

  test('快速连续切换排序时过期响应不能覆盖最终选择', () async {
    final source = _RecordingSource();
    final controller = ReviewMoviesTabController(
      status: 'want_watch',
      type: 'all',
      sortBy: 'create',
      orderBy: 'desc',
      source: source,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final stalePage = Completer<PagedResult<MovieSummary>>();
    source.pending = stalePage;
    final staleRefresh = controller.changeSorting(
      sortBy: 'release',
      orderBy: 'desc',
    );

    final currentPage = Completer<PagedResult<MovieSummary>>();
    source.pending = currentPage;
    final currentRefresh = controller.changeSorting(
      sortBy: 'release',
      orderBy: 'asc',
    );
    currentPage.complete(
      const PagedResult(
        items: [
          MovieSummary(
            id: 'current',
            number: 'CURRENT-1',
            title: '最终排序影片',
            coverUrl: '',
          ),
        ],
        currentPage: 1,
        totalPages: 1,
        total: 1,
      ),
    );
    await currentRefresh;

    stalePage.complete(
      const PagedResult(
        items: [
          MovieSummary(
            id: 'stale',
            number: 'STALE-1',
            title: '过期排序影片',
            coverUrl: '',
          ),
        ],
        currentPage: 1,
        totalPages: 1,
        total: 1,
      ),
    );
    await staleRefresh;

    expect(controller.movies.items.single.id, 'current');
  });
}
