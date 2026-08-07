import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/reviews/models/review_period.dart';
import 'package:jade/features/reviews/services/reviews_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fixture {
  const _Fixture({required this.adapter, required this.service});
  final FakeAdapter adapter;
  final ReviewsService service;
}

Future<_Fixture> _createFixture() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final dm = await DomainManager.load(prefs);
  final dio = Dio(BaseOptions(baseUrl: 'https://jdforrepam.com'));
  dio.interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: dm);
  final adapter = FakeAdapter();
  dio.httpClientAdapter = adapter;
  return _Fixture(adapter: adapter, service: ReviewsService(api));
}

Map<String, dynamic> _response(int count) => {
  'success': 1,
  'data': {
    'reviews': [
      for (var index = 0; index < count; index++)
        {
          'id': index + 1,
          'username': '作者$index',
          'watched_count': 3,
          'content': '内容$index',
          'score': 5,
          'likes_count': 10,
          'created_at': '2026-08-05',
          'movie': {
            'id': 'm$index',
            'number': 'ABC-00$index',
            'title': '影片$index',
            'thumb_url': 'cover-$index.jpg',
            'release_date': '2026-08-05',
          },
        },
    ],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('六周期取值映射', () {
    expect(ReviewPeriod.values.map((period) => period.value), [
      'latest',
      'weekly',
      'monthly',
      'quarterly',
      'yearly',
      'all',
    ]);
  });

  test('携带 period/page/limit 并解析 movie', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(Endpoints.reviewsHotly, _response(1));

    final result = await fixture.service.getHotReviews(
      period: ReviewPeriod.quarterly,
      page: 2,
    );

    expect(fixture.adapter.requests.single.uri.queryParameters, {
      'period': 'quarterly',
      'page': '2',
      'limit': '20',
    });
    final review = result.items.single;
    expect(review.author?.name, '作者0');
    expect(review.movie?.number, 'ABC-000');
    expect(review.movie?.title, '影片0');
    expect(review.movie?.releaseDate, '2026-08-05');
  });

  test('满 20 条时推断存在下一页', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(Endpoints.reviewsHotly, _response(20));

    final result = await fixture.service.getHotReviews(period: ReviewPeriod.all);

    expect(result.currentPage, 1);
    expect(result.totalPages, 2);
  });

  test('不足 20 条时视为最后一页', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(Endpoints.reviewsHotly, _response(5));

    final result = await fixture.service.getHotReviews(period: ReviewPeriod.all);

    expect(result.currentPage, 1);
    expect(result.totalPages, 1);
  });

  test('空列表时不再分页', () async {
    final fixture = await _createFixture();
    fixture.adapter.enqueue(Endpoints.reviewsHotly, _response(0));

    final result = await fixture.service.getHotReviews(period: ReviewPeriod.all);

    expect(result.items, isEmpty);
    expect(result.totalPages, 1);
  });
}
