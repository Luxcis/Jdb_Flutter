import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/articles/services/article_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getArticles 携带 page/limit 参数并解析列表', () async {
    final fixture = await buildArticleFixture();
    fixture.adapter.enqueue(Endpoints.articles, {
      'success': 1,
      'data': {
        'articles': [
          {
            'id': 123,
            'title': '测试资讯',
            'cover_url': '/cover/1.jpg',
            'author': {'name': '作者A'},
            'category': '业界',
            'released_at': '2026-08-05',
          },
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getArticles(page: 1);

    expect(fixture.adapter.requests.single.queryParameters, {
      'page': 1,
      'limit': 48,
    });
    final item = result.items.single;
    expect(item.id, '123');
    expect(item.title, '测试资讯');
    expect(item.author, '作者A');
    expect(item.category, '业界');
    expect(item.releasedAt, '2026-08-05');
  });

  test('author 为字符串时直接使用', () async {
    final fixture = await buildArticleFixture();
    fixture.adapter.enqueue(Endpoints.articles, {
      'success': 1,
      'data': {
        'articles': [
          {'id': 1, 'title': 't', 'author': '作者B'},
        ],
        'current_page': 1,
      },
    });

    final result = await fixture.service.getArticles();

    expect(result.items.single.author, '作者B');
  });

  test('无 total_pages 时按 48 条阈值推断下一页', () async {
    final fixture = await buildArticleFixture();
    fixture.adapter.enqueueSequence(Endpoints.articles, [
      {
        'success': 1,
        'data': {
          'articles': [
            for (var i = 0; i < 48; i++)
              {'id': i, 'title': 't$i'},
          ],
          'current_page': 1,
        },
      },
      {
        'success': 1,
        'data': {
          'articles': [
            {'id': 48, 'title': 't48'},
          ],
          'current_page': 2,
        },
      },
    ]);

    final full = await fixture.service.getArticles();
    final partial = await fixture.service.getArticles(page: 2);

    expect(full.totalPages, 2);
    expect(partial.totalPages, 2);
  });

  test('getArticleDetail 请求 path 参数并解析详情', () async {
    final fixture = await buildArticleFixture();
    fixture.adapter.enqueue('${Endpoints.articles}/456', {
      'success': 1,
      'data': {
        'id': 456,
        'title': '详情标题',
        'author': {'name': '作者C'},
        'category': '新作',
        'image_domain': 'https://img.example.com',
        'content': '<p>正文内容</p>',
        'released_at': '2026-08-05',
      },
    });

    final detail = await fixture.service.getArticleDetail('456');

    expect(fixture.adapter.requests.single.path, '${Endpoints.articles}/456');
    expect(detail.id, '456');
    expect(detail.title, '详情标题');
    expect(detail.author, '作者C');
    expect(detail.imageDomain, 'https://img.example.com');
    expect(detail.content, '<p>正文内容</p>');
  });
}

Future<({FakeAdapter adapter, ArticleService service})>
buildArticleFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: ArticleService(api));
}
