import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/following/screens/follow_tag_movies_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoOpTokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(FakeAdapter, DomainManager)> setup() async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    final adapter = FakeAdapter();
    // ApiClient.create 会设置 _instance 单例，页面通过 instanceOrNull 读取，
    // 因此必须走 create 而非 forTest（后者不写单例，请求不会发出）。
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: _NoOpTokenProvider(),
      onAuthError: () {},
    );
    api.setAdapterForTest(adapter);
    adapter.enqueue(Endpoints.moviesTags, {
      'success': 1,
      'data': {
        'movies': const [],
        'current_page': 1,
        'total_pages': 1,
      },
    });
    return (adapter, dm);
  }

  testWidgets('排序仅含更新日期与发布日期两项', (tester) async {
    await setup();
    await tester.pumpWidget(const MaterialApp(
      home: FollowTagMoviesPage(value: '0:a:g1Q'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('更新日期'), findsOneWidget);
    expect(find.text('发布日期'), findsOneWidget);
    expect(find.text('评分'), findsNothing);
  });

  testWidgets('默认排序为更新日期且请求携带 filter_by', (tester) async {
    final (adapter, _) = await setup();
    await tester.pumpWidget(const MaterialApp(
      home: FollowTagMoviesPage(value: '0:a:g1Q'),
    ));
    await tester.pumpAndSettle();

    final request = adapter.requests.first;
    expect(request.queryParameters['filter_by'], '0:a:g1Q');
    expect(request.queryParameters['sort_by'], 'update');
  });
}
