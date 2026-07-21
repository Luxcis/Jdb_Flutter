import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/network/api_data.dart';

void main() {
  test('normalizeMovieSummaryJson 将数字字符串转为模型可解析的数字', () {
    final movie = MovieSummary.fromJson(
      normalizeMovieSummaryJson({
        'id': 'm1',
        'number': 'ABC-001',
        'title': 'Title',
        'cover_url': 'cover.jpg',
        'duration': '125',
        'score': '8.7',
      }),
    );

    expect(movie.duration, 125);
    expect(movie.score, 8.7);
  });

  test('normalizeMovieSummaryJson 为缺失的影片字符串字段提供兜底值', () {
    final movie = MovieSummary.fromJson(
      normalizeMovieSummaryJson({
        'id': null,
        'number': null,
        'title': null,
        'thumb_url': null,
      }),
    );

    expect(movie.id, '');
    expect(movie.number, '');
    expect(movie.title, '');
    expect(movie.coverUrl, '');
  });

  test('normalizeActorSummaryJson 为缺失的演员字符串字段提供兜底值', () {
    final actor = ActorSummary.fromJson(
      normalizeActorSummaryJson({'id': null, 'name': null, 'avatar': null}),
    );

    expect(actor.id, '');
    expect(actor.name, '');
    expect(actor.avatarUrl, '');
  });

  test('normalizeMovieDetailJson 标准化详情中的演员和数字字段', () {
    final movie = MovieDetail.fromJson(
      normalizeMovieDetailJson({
        'id': 'm1',
        'number': 'ABC-001',
        'title': 'Title',
        'cover_url': 'cover.jpg',
        'magnet_count': '3',
        'want_watch_count': '12',
        'watched_count': '8',
        'actors': [
          {'id': null, 'name': null, 'avatar_url': null},
        ],
      }),
    );

    expect(movie.magnetCount, 3);
    expect(movie.wantWatchCount, 12);
    expect(movie.watchedCount, 8);
    expect(movie.actors.single.id, '');
    expect(movie.actors.single.name, '');
    expect(movie.actors.single.avatarUrl, '');
  });
}
