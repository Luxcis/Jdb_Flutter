import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_data.dart';

void main() {
  test('ReviewMovie 解析 snake_case 字段', () {
    final review = Review.fromJson(
      normalizeReviewJson({
        'id': 242751665,
        'username': 'zy520_jj',
        'watched_count': 65,
        'content': '好看',
        'score': 5,
        'likes_count': 400,
        'created_at': '2026-07-31T13:17:35.000Z',
        'movie': {
          'id': 'GZQMqq',
          'number': 'CAWB-012',
          'title': '测试标题',
          'origin_title': 'テストタイトル',
          'score': '4.56',
          'thumb_url': 'https://tp.spfcas.com/x.jpg',
          'release_date': '2026-08-05',
        },
      }),
    );

    final movie = review.movie;
    expect(movie, isNotNull);
    expect(movie!.id, 'GZQMqq');
    expect(movie.number, 'CAWB-012');
    expect(movie.title, '测试标题');
    expect(movie.originTitle, 'テストタイトル');
    expect(movie.score, '4.56');
    expect(movie.thumbUrl, 'https://tp.spfcas.com/x.jpg');
    expect(movie.releaseDate, '2026-08-05');
    expect(review.id, '242751665');
    expect(review.author?.name, 'zy520_jj');
    expect(review.likedCount, 400);
    expect(review.watchedCount, 65);
  });

  test('movie id 为整数时归一化为字符串', () {
    final review = Review.fromJson(
      normalizeReviewJson({
        'id': 1,
        'movie': {'id': 123, 'number': 'ABC-001'},
      }),
    );
    expect(review.movie?.id, '123');
  });

  test('无 movie 字段时 movie 为 null', () {
    final review = Review.fromJson(normalizeReviewJson({'id': '1', 'username': 'u'}));
    expect(review.movie, isNull);
  });
}
