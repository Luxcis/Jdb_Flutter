import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/review_api.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fixture {
  const _Fixture({required this.adapter, required this.api});
  final FakeAdapter adapter;
  final ReviewApi api;
}

Future<_Fixture> _createFixture() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  final dio = Dio(BaseOptions(baseUrl: 'https://jdforrepam.com'));
  dio.interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final apiClient = ApiClient.forTest(dio: dio, domainManager: dm);
  final adapter = FakeAdapter();
  dio.httpClientAdapter = adapter;
  return _Fixture(adapter: adapter, api: ReviewApi(apiClient));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('likeReview 发送 POST 到影片与评论组成的路径', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue('/api/v1/movies/m1/reviews/r9/like', {
      'success': 1,
      'data': null,
    });

    await fixture.api.likeReview(movieId: 'm1', reviewId: 'r9');

    final request = fixture.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/movies/m1/reviews/r9/like');
  });

  test('likeReview 正确替换路径中的 movie_id 与 review_id', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(
      '/api/v1/movies/m-42/reviews/r-7/like',
      {'success': 1, 'data': null},
    );

    await fixture.api.likeReview(movieId: 'm-42', reviewId: 'r-7');

    expect(
      fixture.adapter.requests.single.path,
      '/api/v1/movies/m-42/reviews/r-7/like',
    );
  });

  test('点赞失败时抛出异常', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue('/api/v1/movies/m1/reviews/r9/like', {
      'success': 0,
      'message': '失败',
    });

    await expectLater(
      fixture.api.likeReview(movieId: 'm1', reviewId: 'r9'),
      throwsA(isA<DioException>()),
    );
  });
}
