import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({FakeAdapter adapter, FollowingTagsService service})>
buildFollowingFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: FollowingTagsService(api));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('follow 发送 name/value 并解析返回 data 为 FollowTagItem', () async {
    final fixture = await buildFollowingFixture();
    fixture.adapter.enqueue(Endpoints.followingTags, {
      'success': 1,
      'data': {
        'id': 13384922,
        'name': '有碼,森螢',
        'value': '0:a:g1Q',
        'priority': 6.0,
      },
    });

    final item = await fixture.service.follow(name: '有碼,森螢', value: '0:a:g1Q');

    expect(item.id, '13384922');
    expect(item.name, '有碼,森螢');
    expect(item.value, '0:a:g1Q');
    expect(fixture.adapter.requests.single.data, {
      'name': '有碼,森螢',
      'value': '0:a:g1Q',
    });
  });

  test('unfollow 调用 DELETE 且路径拼接 id', () async {
    final fixture = await buildFollowingFixture();
    fixture.adapter.enqueue('${Endpoints.followingTags}/12345', {
      'success': 1,
    });

    await fixture.service.unfollow('12345');

    expect(
      fixture.adapter.requests.single.path,
      '${Endpoints.followingTags}/12345',
    );
  });

  test('batchPush 发送 tags 数组并解析远程 following_tags', () async {
    final fixture = await buildFollowingFixture();
    fixture.adapter.enqueue(Endpoints.followingTagsBatchPush, {
      'success': 1,
      'data': {
        'following_tags': [
          {'id': 1, 'name': 'a', 'value': 'v1'},
          {'id': 2, 'name': 'b', 'value': 'v2'},
        ],
      },
    });

    final result = await fixture.service.batchPush(const [
      FollowTagItem(id: '1', name: 'a', value: 'v1'),
    ]);

    expect(result.length, 2);
    expect(result[0].id, '1');
    expect(result[1].id, '2');
    expect(fixture.adapter.requests.single.data['tags'], [
      {'name': 'a', 'value': 'v1'},
    ]);
  });
}
