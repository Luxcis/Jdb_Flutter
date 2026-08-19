import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/profile/services/user_lists_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({FakeAdapter adapter, UserListsService service})>
buildUserListsFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: UserListsService(api));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getMyLists 发送 sort_by 必填参数并解析 lists 分页', () async {
    final fixture = await buildUserListsFixture();
    fixture.adapter.enqueue(Endpoints.lists, {
      'success': 1,
      'data': {
        'lists': [
          {
            'id': 'l1',
            'name': '我的收藏',
            'movies_count': 12,
            'views_count': 34,
            'created_at': '2026-08-01 10:00:00',
          },
        ],
        'current_page': 1,
        'total_pages': 2,
        'total': 25,
      },
    });

    final result = await fixture.service.getMyLists(sortBy: 'updated_at');

    expect(result.items.single.id, 'l1');
    expect(result.items.single.name, '我的收藏');
    expect(result.items.single.movieCount, 12);
    expect(result.items.single.viewedCount, 34);
    expect(result.items.single.createdAt, '2026-08-01 10:00:00');
    expect(result.currentPage, 1);
    expect(result.totalPages, 2);
    expect(fixture.adapter.requests.single.queryParameters, {
      'sort_by': 'updated_at',
      'page': 1,
      'limit': 48,
    });
  });

  test('renameList 发送 PUT 到 /api/v1/lists/{id} body 为 JSON name', () async {
    final fixture = await buildUserListsFixture();
    fixture.adapter.enqueue('${Endpoints.lists}/l1', {
      'success': 1,
      'data': null,
    });

    await fixture.service.renameList(id: 'l1', name: '新名称');

    final request = fixture.adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '${Endpoints.lists}/l1');
    expect(request.data, {'name': '新名称'});
  });

  test('deleteList 发送 DELETE 到 /api/v1/lists/{id}', () async {
    final fixture = await buildUserListsFixture();
    fixture.adapter.enqueue('${Endpoints.lists}/l1', {
      'success': 1,
      'data': null,
    });

    await fixture.service.deleteList('l1');

    final request = fixture.adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '${Endpoints.lists}/l1');
  });
}
