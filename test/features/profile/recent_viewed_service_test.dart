import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/profile/services/recent_viewed_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getRecentViewed 发送 page 与 limit=48 查询参数', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.usersRecentViewed, {
      'success': 1,
      'data': {'movies': [], 'current_page': 1},
    });

    await fixture.service.getRecentViewed(page: 2);

    expect(fixture.adapter.requests.single.path, Endpoints.usersRecentViewed);
    expect(fixture.adapter.requests.single.queryParameters, {
      'page': 2,
      'limit': 48,
    });
  });

  test('getRecentViewed 解析 movies 并保留影片摘要字段', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue(Endpoints.usersRecentViewed, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'm1',
            'number': 'SSIS-001',
            'title': '测试影片',
            'thumb_url': 'thumb.jpg',
            'cover_url': 'cover.jpg',
            'release_date': '2026-08-01',
          },
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getRecentViewed();

    expect(result.items.single.id, 'm1');
    expect(result.items.single.number, 'SSIS-001');
    expect(result.items.single.thumbUrl, 'thumb.jpg');
    expect(result.currentPage, 1);
  });

  test('getRecentViewed 缺少 total_pages 时以 48 条为满页阈值', () async {
    final fixture = await _buildFixture();
    // 同 path 多次响应必须用 enqueueSequence：enqueue 按 path 覆盖。
    fixture.adapter.enqueueSequence(Endpoints.usersRecentViewed, [
      {
        'success': 1,
        'data': {
          'movies': [
            for (var index = 0; index < 48; index++)
              {
                'id': 'm$index',
                'number': 'N$index',
                'title': '影片 $index',
                'cover_url': '',
              },
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'movies': [
            {'id': 'm48', 'number': 'N48', 'title': '影片 48', 'cover_url': ''},
          ],
          'current_page': 2,
        },
      },
    ]);

    final fullPage = await fixture.service.getRecentViewed();
    final partialPage = await fixture.service.getRecentViewed(page: 2);

    expect(fullPage.totalPages, 2);
    expect(partialPage.totalPages, 2);
  });

  test('clearRecentViewed 发送 DELETE 请求', () async {
    final fixture = await _buildFixture();
    // FakeAdapter 按 path 匹配、不区分 method；DELETE 响应同样入队。
    fixture.adapter.enqueue(Endpoints.usersRecentViewed, {
      'success': 1,
      'data': null,
    });

    await fixture.service.clearRecentViewed();

    final request = fixture.adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, Endpoints.usersRecentViewed);
  });
}

Future<({FakeAdapter adapter, RecentViewedService service})>
_buildFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: RecentViewedService(api));
}
