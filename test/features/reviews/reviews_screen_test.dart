import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/review_tile.dart';
import 'package:jade/features/reviews/screens/reviews_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

Map<String, dynamic> _pageResponse(int count, {int start = 0}) => {
  'success': 1,
  'data': {
    'reviews': [
      for (var index = 0; index < count; index++)
        {
          'id': start + index + 1,
          'username': '作者${start + index}',
          'watched_count': 3,
          'content': '内容${start + index}',
          'score': 5,
          'likes_count': 17,
          'created_at': '2016-09-24',
          'movie': {
            'id': 'm${start + index}',
            'number': 'ABC-00${start + index}',
            'title': '影片${start + index}',
            'thumb_url': 'cover-${start + index}.jpg',
            'release_date': '2026-08-05',
          },
        },
    ],
  },
};

Future<FakeAdapter> _pumpReviews(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.baseUrl: 'https://jdforrepam.com',
    StorageKeys.apiDomains: ['https://jdforrepam.com'],
  });
  final prefs = await SharedPreferences.getInstance();
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: _TokenProvider(),
    onAuthError: () {},
  );
  final adapter = FakeAdapter();
  api.setAdapterForTest(adapter);
  await tester.pumpWidget(const MaterialApp(home: ReviewsPage()));
  return adapter;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var i = 0; i < 20; i++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('默认 Tab 请求 latest 并渲染评论卡片', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.enqueue(Endpoints.reviewsHotly, _pageResponse(1));

    await _pumpUntil(tester, () => adapter.requests.isNotEmpty);

    expect(find.text('看短评'), findsOneWidget);
    for (final tab in ['最新', '上周热评', '月度热评', '季度热评', '年度热评', '全部']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(adapter.requests.single.uri.queryParameters['period'], 'latest');
    expect(find.byType(ReviewTile), findsOneWidget);
    expect(find.text('内容0'), findsOneWidget);
  });

  testWidgets('切换 Tab 请求对应周期', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.enqueue(Endpoints.reviewsHotly, _pageResponse(1));
    await _pumpUntil(tester, () => adapter.requests.isNotEmpty);

    await tester.tap(find.text('年度热评'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _pumpUntil(
      tester,
      () => adapter.requests.any(
        (request) => request.uri.queryParameters['period'] == 'yearly',
      ),
    );

    expect(
      adapter.requests
          .where((request) => request.path == Endpoints.reviewsHotly)
          .last
          .uri
          .queryParameters['period'],
      'yearly',
    );
  });

  testWidgets('滚动到底部请求下一页', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.enqueue(Endpoints.reviewsHotly, _pageResponse(20));
    await _pumpUntil(tester, () => adapter.requests.isNotEmpty);
    await _pumpUntil(tester, () => find.byType(ReviewTile).evaluate().isNotEmpty);

    await tester.drag(find.byType(ListView), const Offset(0, -10000));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => adapter.requests.any(
        (request) => request.uri.queryParameters['page'] == '2',
      ),
    );

    expect(
      adapter.requests
          .where((request) => request.path == Endpoints.reviewsHotly)
          .last
          .uri
          .queryParameters['page'],
      '2',
    );
  });

  testWidgets('请求失败显示错误并可重试', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.enqueueSequence(
      Endpoints.reviewsHotly,
      [
        {'success': 0, 'message': '失败'},
        _pageResponse(1),
      ],
    );
    await _pumpUntil(
      tester,
      () => find.byType(ErrorRetryWidget).evaluate().isNotEmpty,
    );

    await tester.tap(find.text('重试'));
    await _pumpUntil(tester, () => find.byType(ReviewTile).evaluate().isNotEmpty);

    expect(find.byType(ReviewTile), findsOneWidget);
  });

  testWidgets('空列表显示暂无短评', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.enqueue(Endpoints.reviewsHotly, _pageResponse(0));
    await _pumpUntil(tester, () => find.text('暂无短评').evaluate().isNotEmpty);

    expect(find.text('暂无短评'), findsOneWidget);
  });

  testWidgets('下拉刷新保留短评列表并显示顶部指示器，成功后替换', (tester) async {
    final adapter = await _pumpReviews(tester);
    adapter.responseDelay = const Duration(milliseconds: 200);
    adapter.enqueueSequence(
      Endpoints.reviewsHotly,
      [_pageResponse(1), _pageResponse(1, start: 1)],
    );
    await _pumpUntil(tester, () => find.byType(ReviewTile).evaluate().isNotEmpty);
    expect(find.text('内容0'), findsOneWidget);

    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();

    expect(find.text('内容0'), findsOneWidget);
    expect(find.byKey(const Key('reviews-refreshing')), findsOneWidget);

    adapter.responseDelay = Duration.zero;
    await _pumpUntil(
      tester,
      () => adapter.requests.length >= 2,
    );
    await refresh;

    expect(find.text('内容0'), findsNothing);
    expect(find.text('内容1'), findsOneWidget);
    expect(find.byKey(const Key('reviews-refreshing')), findsNothing);
  });
}
