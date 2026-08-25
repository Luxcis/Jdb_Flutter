import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/screens/follow_tag_movies_page.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:jade/features/following/services/following_tags_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoOpTokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

class _MemoryStore implements FollowingTagsStore {
  @override
  Future<void> clear() async {}
  @override
  Future<List<FollowTagItem>> load() async => const [];
  @override
  Future<void> save(List<FollowTagItem> tags) async {}
}

class _FakeData implements FollowingTagsDataSource {
  @override
  Future<FollowTagItem> follow({required String name, required String value}) async =>
      FollowTagItem(id: 'n', name: name, value: value);
  @override
  Future<void> unfollow(String id) async {}
  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async => tags;
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

  Future<void> pumpPage(
    WidgetTester tester, {
    String value = '0:a:g1Q',
    List<FollowTagItem> tags = const [],
  }) async {
    final provider = FollowingTagsProvider(
      store: _MemoryStore(),
      dataSource: _FakeData(),
    );
    await provider.initialize();
    if (tags.isNotEmpty) {
      await provider.syncFromLogin(tags);
    }
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider.value(value: provider)],
      child: MaterialApp(home: FollowTagMoviesPage(value: value)),
    ));
  }

  testWidgets('排序仅含更新日期与发布日期两项', (tester) async {
    await setup();
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('更新日期'), findsOneWidget);
    expect(find.text('发布日期'), findsOneWidget);
    expect(find.text('评分'), findsNothing);
  });

  testWidgets('默认排序为更新日期且请求携带 filter_by', (tester) async {
    final (adapter, _) = await setup();
    await pumpPage(tester);
    await tester.pumpAndSettle();

    final request = adapter.requests.first;
    expect(request.queryParameters['filter_by'], '0:a:g1Q');
    expect(request.queryParameters['sort_by'], 'update');
  });

  testWidgets('导航栏标题使用关注标签名称', (tester) async {
    await setup();
    await pumpPage(tester, tags: const [
      FollowTagItem(id: '1', name: '有碼,森螢', value: '0:a:g1Q'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('有碼,森螢'), findsOneWidget);
    expect(find.text('标签影片'), findsNothing);
  });

  testWidgets('无匹配关注标签时导航栏标题回退', (tester) async {
    await setup();
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('标签影片'), findsOneWidget);
  });
}
