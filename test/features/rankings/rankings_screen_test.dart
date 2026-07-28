import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/rankings/screens/rankings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RankingFixture {
  const _RankingFixture(this.adapter);

  final FakeAdapter adapter;
}

Future<_RankingFixture> _pumpRankings(
  WidgetTester tester, {
  Duration responseDelay = Duration.zero,
  bool loggedIn = true,
  double textScaleFactor = 1,
}) async {
  SharedPreferences.setMockInitialValues({
    'key_baseurl': 'https://jdforrepam.com',
    'key_api_domains': ['https://jdforrepam.com'],
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  if (loggedIn) {
    await auth.login(token: 'token', user: {'id': 1});
  }
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: auth,
    onAuthError: auth.logout,
  );
  final adapter = FakeAdapter()..responseDelay = responseDelay;
  api.setAdapterForTest(adapter);
  for (final path in [
    Endpoints.moviesTop,
    Endpoints.rankingsPlayback,
    Endpoints.rankings,
  ]) {
    adapter.enqueue(path, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': path,
            'number': 'ABC-001',
            'title': path == Endpoints.rankingsPlayback
                ? 'Hot Movie'
                : 'Ranked Movie',
            'cover_url': 'cover.jpg',
          },
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
    });
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const RankingsPage(),
        ),
      ),
    ),
  );
  return _RankingFixture(adapter);
}

Future<void> _pumpRankingFrame(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _showTab(WidgetTester tester, int targetIndex) async {
  final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
  controller.animateTo(targetIndex);
  await tester.pump();
  await _pumpRankingFrame(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('切换到看热播时先显示 Loading 且不显示空网格', (tester) async {
    final fixture = await _pumpRankings(
      tester,
      responseDelay: const Duration(seconds: 1),
    );

    await _showTab(tester, 1);

    expect(find.byKey(const Key('movie-grid-initial-loading')), findsWidgets);
    expect(find.byType(GridView), findsNothing);
    expect(
      fixture.adapter.requests.map((request) => request.path),
      contains(Endpoints.rankingsPlayback),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  });

  testWidgets('看热播使用分组圆角标签并发送 OpenAPI 参数', (tester) async {
    final fixture = await _pumpRankings(tester);
    await _showTab(tester, 1);

    expect(find.text('范围'), findsOneWidget);
    expect(find.text('周期'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(5));
    await tester.tap(find.widgetWithText(ChoiceChip, '周榜'));
    await _pumpRankingFrame(tester);

    final query = fixture.adapter.requests
        .where((request) => request.path == Endpoints.rankingsPlayback)
        .last
        .uri
        .queryParameters;
    expect(query['filter_by'], 'high_score');
    expect(query['period'], 'weekly');
  });

  testWidgets('综合排行榜没有演员月榜且类型映射从 0 开始', (tester) async {
    final fixture = await _pumpRankings(tester);
    await _showTab(tester, 2);

    expect(find.text('演员月榜'), findsNothing);
    final rankingTypes = fixture.adapter.requests
        .where((request) => request.path == Endpoints.rankings)
        .map((request) => request.uri.queryParameters['type']);
    expect(rankingTypes, contains('0'));
  });

  testWidgets('离开已加载 Tab 后返回时保留内容且不重复请求', (tester) async {
    final fixture = await _pumpRankings(tester);
    await _showTab(tester, 1);
    final playbackCount = fixture.adapter.requests
        .where((request) => request.path == Endpoints.rankingsPlayback)
        .length;

    await _showTab(tester, 0);
    await _showTab(tester, 1);

    expect(find.text('Hot Movie'), findsOneWidget);
    expect(
      fixture.adapter.requests
          .where((request) => request.path == Endpoints.rankingsPlayback)
          .length,
      playbackCount,
    );
  });

  testWidgets('看热播筛选在窄屏大字体下不溢出', (tester) async {
    await _pumpRankings(tester, textScaleFactor: 1.5);
    await _showTab(tester, 1);

    expect(find.text('高分'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
