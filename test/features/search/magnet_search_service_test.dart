import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/search/models/magnet_search_sort.dart';
import 'package:jade/features/search/services/magnet_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('四种排序映射到接口值和中文标签', () {
    expect(MagnetSearchSort.values.map((value) => value.apiValue), [
      'relevance',
      'created',
      'files',
      'size',
    ]);
    expect(MagnetSearchSort.values.map((value) => value.label), [
      '相关度',
      '时间',
      '文件数',
      '文件大小',
    ]);
  });

  test('磁链搜索携带完整参数并解析分页响应', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(Endpoints.searchMagnet, {
      'success': 1,
      'data': {
        'magnets': [
          {
            'hash': 'hash-1',
            'name': '桥本香菜.torrent',
            'size': 1048576,
            'files_count': 3,
            'created_at': '2026-08-03',
          },
        ],
        'current_page': 2,
      },
    });

    final result = await fixture.service.getMagnets(
      query: '桥本香菜',
      sort: MagnetSearchSort.created,
      fromRecent: true,
      page: 2,
    );

    expect(fixture.adapter.requests.single.queryParameters, {
      'q': '桥本香菜',
      'sort_by': 'created',
      'from_recent': 'true',
      'page': 2,
      'limit': 48,
    });
    expect(result.items.single.title, '桥本香菜.torrent');
    expect(result.items.single.filesCount, 3);
    expect(result.items.single.publishDate, '2026-08-03');
    expect(result.currentPage, 2);
    expect(result.totalPages, 3);
  });

  test('满 48 条时推断存在下一页', () async {
    final fixture = await _createFixture();
    _enqueuePage(fixture.adapter, itemCount: 48);

    final result = await fixture.service.getMagnets(
      query: '桥本香菜',
      sort: MagnetSearchSort.relevance,
      fromRecent: false,
    );

    expect(result.currentPage, 1);
    expect(result.totalPages, 2);
  });

  test('服务端返回 40 条时仍继续探测下一页', () async {
    final fixture = await _createFixture();
    _enqueuePage(fixture.adapter, itemCount: 40);

    final result = await fixture.service.getMagnets(
      query: '桥本香菜',
      sort: MagnetSearchSort.relevance,
      fromRecent: false,
    );

    expect(result.currentPage, 1);
    expect(result.totalPages, 2);
  });

  test('空页停止继续分页', () async {
    final fixture = await _createFixture();
    _enqueuePage(fixture.adapter, itemCount: 0, currentPage: 2);

    final result = await fixture.service.getMagnets(
      query: '桥本香菜',
      sort: MagnetSearchSort.relevance,
      fromRecent: false,
      page: 2,
    );

    expect(result.currentPage, 2);
    expect(result.totalPages, 2);
  });
}

Future<({FakeAdapter adapter, MagnetSearchService service})>
_createFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: MagnetSearchService(api));
}

void _enqueuePage(
  FakeAdapter adapter, {
  required int itemCount,
  int currentPage = 1,
}) {
  adapter.enqueue(Endpoints.searchMagnet, {
    'success': 1,
    'data': {
      'magnets': [
        for (var index = 0; index < itemCount; index++)
          {
            'hash': 'hash-$index',
            'name': '磁链 $index',
            'size': 1024,
            'files_count': 1,
          },
      ],
      'current_page': currentPage,
    },
  });
}
