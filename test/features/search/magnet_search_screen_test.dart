import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/features/search/screens/magnet_search_screen.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SearchHistoryStore> _magnetStore(List<String> history) async {
  SharedPreferences.setMockInitialValues({
    if (history.isNotEmpty)
      StorageKeys.magnetSearchHistory: jsonEncode(history),
  });
  return SearchHistoryStore(
    await SharedPreferences.getInstance(),
    storageKey: StorageKeys.magnetSearchHistory,
  );
}

GoRouter _router({
  required SearchHistoryStore store,
  List<String> recentKeywords = const [],
}) {
  return GoRouter(
    initialLocation: AppRoutes.magnetSearch,
    routes: [
      GoRoute(
        path: AppRoutes.magnetSearch,
        builder: (_, _) => MagnetSearchPage(
          historyStore: store,
          recentKeywords: recentKeywords,
        ),
        routes: [
          GoRoute(
            path: 'results',
            builder: (_, state) => Scaffold(
              body: Text(
                '结果 ${state.uri.queryParameters['q']} '
                '${state.uri.queryParameters['from_recent']}',
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('显示独立历史和 startup 磁链热词', (tester) async {
    final store = await _magnetStore(const ['历史磁链']);
    await tester.pumpWidget(
      MaterialApp(
        home: MagnetSearchPage(
          historyStore: store,
          recentKeywords: const ['近期磁链'],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('历史搜索'), findsOneWidget);
    expect(find.text('历史磁链'), findsOneWidget);
    expect(find.text('近期热搜'), findsOneWidget);
    expect(find.text('近期磁链'), findsOneWidget);
  });

  testWidgets('点击历史词使用 from_recent true', (tester) async {
    final store = await _magnetStore(const ['历史磁链']);
    final router = _router(store: store);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    await tester.tap(find.text('历史磁链'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.magnetSearchResults);
    expect(router.state.uri.queryParameters, {
      'q': '历史磁链',
      'from_recent': 'true',
    });
  });

  testWidgets('点击近期热词使用 from_recent false', (tester) async {
    final store = await _magnetStore(const []);
    final router = _router(store: store, recentKeywords: const ['近期磁链']);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    await tester.tap(find.text('近期磁链'));
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters, {
      'q': '近期磁链',
      'from_recent': 'false',
    });
    expect(store.load().first, '近期磁链');
  });

  testWidgets('手动搜索 trim 后使用 from_recent false', (tester) async {
    final store = await _magnetStore(const []);
    final router = _router(store: store);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    await tester.enterText(find.byType(TextField), ' 手输磁链 ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters, {
      'q': '手输磁链',
      'from_recent': 'false',
    });
    expect(store.load().first, '手输磁链');
  });

  testWidgets('清空磁链历史不影响普通搜索历史', (tester) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.searchHistory: jsonEncode(['普通历史']),
      StorageKeys.magnetSearchHistory: jsonEncode(['磁链历史']),
    });
    final prefs = await SharedPreferences.getInstance();
    final ordinary = SearchHistoryStore(prefs);
    final magnet = SearchHistoryStore(
      prefs,
      storageKey: StorageKeys.magnetSearchHistory,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MagnetSearchPage(historyStore: magnet, recentKeywords: const []),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('清空'));
    await tester.pump();

    expect(find.text('磁链历史'), findsNothing);
    expect(magnet.load(), isEmpty);
    expect(ordinary.load(), ['普通历史']);
  });
}
