import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/magnet_list_tile.dart';
import 'package:jade/features/search/models/magnet_search_sort.dart';
import 'package:jade/features/search/screens/magnet_search_results_screen.dart';
import 'package:jade/features/search/services/magnet_search_service.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Call = ({
  String query,
  MagnetSearchSort sort,
  bool fromRecent,
  int page,
});
typedef _Handler = Future<PagedResult<Magnet>> Function(_Call call);

class _RecordingDataSource implements MagnetSearchDataSource {
  _RecordingDataSource(this.handler);

  final _Handler handler;
  final calls = <_Call>[];

  @override
  Future<PagedResult<Magnet>> getMagnets({
    required String query,
    required MagnetSearchSort sort,
    required bool fromRecent,
    int page = 1,
  }) {
    final call = (query: query, sort: sort, fromRecent: fromRecent, page: page);
    calls.add(call);
    return handler(call);
  }
}

Magnet _magnet(String hash, String title) => Magnet(
  hash: hash,
  title: title,
  size: '1 MB',
  filesCount: 2,
  publishDate: '2026-08-03',
);

PagedResult<Magnet> _page(
  List<Magnet> items, {
  int currentPage = 1,
  int totalPages = 1,
}) {
  return PagedResult(
    items: items,
    currentPage: currentPage,
    totalPages: totalPages,
    total: items.length,
  );
}

Future<SearchHistoryStore> _historyStore() async {
  SharedPreferences.setMockInitialValues({});
  return SearchHistoryStore(
    await SharedPreferences.getInstance(),
    storageKey: 'test_magnet_history',
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required MagnetSearchDataSource dataSource,
  String query = '桥本香菜',
  bool fromRecent = true,
  SearchHistoryStore? historyStore,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MagnetSearchResultsPage(
        key: ValueKey(dataSource),
        query: query,
        fromRecent: fromRecent,
        dataSource: dataSource,
        historyStore: historyStore,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('默认相关度并使用排行榜同款四项紧凑排序', (tester) async {
    final dataSource = _RecordingDataSource(
      (_) async => _page([_magnet('hash-1', '相关度结果')]),
    );

    await _pumpPage(tester, dataSource: dataSource);
    await tester.pumpAndSettle();

    expect(dataSource.calls.single, (
      query: '桥本香菜',
      sort: MagnetSearchSort.relevance,
      fromRecent: true,
      page: 1,
    ));
    final segmented = tester.widget<SegmentedButton<MagnetSearchSort>>(
      find.byType(SegmentedButton<MagnetSearchSort>),
    );
    expect(segmented.showSelectedIcon, isFalse);
    expect(segmented.expandedInsets, EdgeInsets.zero);
    expect(segmented.style?.visualDensity, VisualDensity.compact);
    expect(find.text('相关度'), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('文件数'), findsOneWidget);
    expect(find.text('文件大小'), findsOneWidget);
    expect(find.byType(MagnetListTile), findsOneWidget);
  });

  testWidgets('切换排序后从第一页刷新并替换旧结果', (tester) async {
    final dataSource = _RecordingDataSource(
      (call) async => _page([
        _magnet('hash-${call.sort.apiValue}', '${call.sort.label}结果'),
      ]),
    );

    await _pumpPage(tester, dataSource: dataSource);
    await tester.pumpAndSettle();
    expect(find.text('相关度结果'), findsOneWidget);

    await tester.tap(find.text('时间'));
    await tester.pumpAndSettle();

    expect(dataSource.calls.last.sort, MagnetSearchSort.created);
    expect(dataSource.calls.last.page, 1);
    expect(find.text('时间结果'), findsOneWidget);
    expect(find.text('相关度结果'), findsNothing);
  });

  testWidgets('首屏加载、空结果和首屏失败重试状态正确', (tester) async {
    final completer = Completer<PagedResult<Magnet>>();
    final dataSource = _RecordingDataSource((_) => completer.future);

    await _pumpPage(tester, dataSource: dataSource);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_page(const []));
    await tester.pumpAndSettle();
    expect(find.text('未找到相关磁链'), findsOneWidget);

    var shouldFail = true;
    final retrySource = _RecordingDataSource((_) async {
      if (shouldFail) throw Exception('network');
      return _page([_magnet('retry', '重试成功')]);
    });
    await _pumpPage(tester, dataSource: retrySource);
    await tester.pumpAndSettle();
    expect(find.text('磁链搜索失败'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('重试成功'), findsOneWidget);
  });

  testWidgets('滚动加载下一页且追加失败可保留并重试', (tester) async {
    var pageTwoAttempts = 0;
    final dataSource = _RecordingDataSource((call) async {
      if (call.page == 1) {
        return _page([
          for (var index = 0; index < 20; index++)
            _magnet('page-1-$index', '第一页磁链 $index'),
        ], totalPages: 2);
      }
      pageTwoAttempts += 1;
      if (pageTwoAttempts == 1) throw Exception('page two failed');
      return _page([_magnet('page-2', '第二页磁链')], currentPage: 2, totalPages: 2);
    });

    await _pumpPage(tester, dataSource: dataSource);
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(const Key('magnet-results-list')),
      const Offset(0, -2400),
      3000,
    );
    await tester.pumpAndSettle();

    expect(dataSource.calls.map((call) => call.page), [1, 2]);
    expect(find.byType(MagnetListTile), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('magnet-load-more-retry')),
      400,
      scrollable: find.descendant(
        of: find.byKey(const Key('magnet-results-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const Key('magnet-load-more-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('magnet-load-more-retry')));
    await tester.pumpAndSettle();

    expect(dataSource.calls.map((call) => call.page), [1, 2, 2]);
    expect(find.text('第二页磁链'), findsOneWidget);
  });

  testWidgets('结果项复制磁链且重新搜索替换路由并标记非历史', (tester) async {
    MethodCall? clipboardCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboardCall = call;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final store = await _historyStore();
    final dataSource = _RecordingDataSource(
      (_) async => _page([_magnet('copy-hash', '可复制磁链')]),
    );
    late final GoRouter router;
    router = GoRouter(
      initialLocation:
          '${AppRoutes.magnetSearchResults}?q=旧关键词&from_recent=true',
      routes: [
        GoRoute(
          path: AppRoutes.magnetSearch,
          builder: (_, _) => const Scaffold(body: Text('磁链首页')),
          routes: [
            GoRoute(
              path: 'results',
              builder: (_, state) => MagnetSearchResultsPage(
                query: state.uri.queryParameters['q']!,
                fromRecent: state.uri.queryParameters['from_recent'] == 'true',
                dataSource: dataSource,
                historyStore: store,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('可复制磁链'));
    await tester.pump();
    expect(clipboardCall?.arguments, {'text': 'magnet:?xt=urn:btih:copy-hash'});

    await tester.enterText(find.byType(TextField), ' 新关键词 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.magnetSearchResults);
    expect(router.state.uri.queryParameters, {
      'q': '新关键词',
      'from_recent': 'false',
    });
    expect(store.load().first, '新关键词');
  });
}
