import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/movie_detail/models/movie_review_status.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fixture {
  const _Fixture({required this.adapter, required this.service});

  final FakeAdapter adapter;
  final MovieDetailService service;
}

Future<_Fixture> _buildFixture() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(prefs);
  final dio = Dio(BaseOptions(baseUrl: 'https://jdforrepam.com'))
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  final adapter = FakeAdapter();
  dio.httpClientAdapter = adapter;
  return _Fixture(adapter: adapter, service: MovieDetailService(api));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('想看只发送 status JSON 并解析返回 review', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue('/api/v1/movies/m1/reviews', {
      'success': 1,
      'data': {
        'review': {'id': 10, 'status': 'want_watch'},
      },
    });

    final review = await fixture.service.createOrUpdateReview(
      movieId: 'm1',
      status: MovieReviewStatus.wantWatch,
    );

    final request = fixture.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.data, {'status': 'want_watch'});
    expect(review.id, '10');
    expect(review.status, 'want_watch');
  });

  test('想看忽略调用方传入的评分和评论', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue('/api/v1/movies/m1/reviews', {
      'success': 1,
      'data': {
        'review': {'id': 11, 'status': 'want_watch'},
      },
    });

    await fixture.service.createOrUpdateReview(
      movieId: 'm1',
      status: MovieReviewStatus.wantWatch,
      score: 5,
      content: '会被忽略',
    );

    expect(fixture.adapter.requests.single.data, {'status': 'want_watch'});
  });

  test('看过发送 1 到 5 分 裁剪评论和 watched 状态', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue('/api/v1/movies/m1/reviews', {
      'success': 1,
      'data': {
        'review': {
          'id': 'r1',
          'status': 'watched',
          'score': 5,
          'content': '评论内容',
        },
      },
    });

    await fixture.service.createOrUpdateReview(
      movieId: 'm1',
      status: MovieReviewStatus.watched,
      score: 5,
      content: '  评论内容  ',
    );

    expect(fixture.adapter.requests.single.data, {
      'score': 5,
      'content': '评论内容',
      'status': 'watched',
    });
  });

  test('看过接受 1 分边界值', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue('/api/v1/movies/m1/reviews', {
      'success': 1,
      'data': {
        'review': {
          'id': 'r-min',
          'status': 'watched',
          'score': 1,
          'content': '最低分评论',
        },
      },
    });

    await fixture.service.createOrUpdateReview(
      movieId: 'm1',
      status: MovieReviewStatus.watched,
      score: 1,
      content: '最低分评论',
    );

    expect(fixture.adapter.requests.single.data['score'], 1);
  });

  test('看过在评分或评论无效时不发送请求', () async {
    for (final input in <({int? score, String? content})>[
      (score: null, content: '评论'),
      (score: 0, content: '评论'),
      (score: 6, content: '评论'),
      (score: 3, content: null),
      (score: 3, content: ''),
      (score: 3, content: '   '),
    ]) {
      final fixture = await _buildFixture();

      await expectLater(
        fixture.service.createOrUpdateReview(
          movieId: 'm1',
          status: MovieReviewStatus.watched,
          score: input.score,
          content: input.content,
        ),
        throwsArgumentError,
      );
      expect(fixture.adapter.requests, isEmpty);
    }
  });

  test('响应缺少或非对象 review 时抛出 FormatException', () async {
    for (final responseData in <Map<String, dynamic>>[
      {},
      {'review': null},
      {'review': 'invalid'},
    ]) {
      final fixture = await _buildFixture();
      fixture.adapter.enqueue('/api/v1/movies/m1/reviews', {
        'success': 1,
        'data': responseData,
      });

      await expectLater(
        fixture.service.createOrUpdateReview(
          movieId: 'm1',
          status: MovieReviewStatus.wantWatch,
        ),
        throwsFormatException,
      );
      expect(fixture.adapter.requests, hasLength(1));
      expect(fixture.adapter.requests.single.method, 'POST');
      expect(fixture.adapter.requests.single.path, '/api/v1/movies/m1/reviews');
    }
  });

  test('删除影评使用 movie ID 与 review ID 组成路径', () async {
    final fixture = await _buildFixture();
    fixture.adapter.enqueue('/api/v1/movies/m1/reviews/r9', {
      'success': 1,
      'data': {'review': null},
    });

    await fixture.service.deleteReview(movieId: 'm1', reviewId: 'r9');

    expect(fixture.adapter.requests.single.method, 'DELETE');
    expect(
      fixture.adapter.requests.single.path,
      '/api/v1/movies/m1/reviews/r9',
    );
  });
}
