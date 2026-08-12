import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';

void main() {
  test('TopRanking 解析 ranking/title/top_type 字段', () {
    final ranking = TopRanking.fromJson({
      'ranking': 1,
      'title': '全网热播榜',
      'top_type': 2,
    });

    expect(ranking.ranking, 1);
    expect(ranking.title, '全网热播榜');
    expect(ranking.topType, 2);
  });

  test('TopRanking 字段缺失时各字段为 null', () {
    final ranking = TopRanking.fromJson({});

    expect(ranking.ranking, isNull);
    expect(ranking.title, isNull);
    expect(ranking.topType, isNull);
  });

  test('MovieDetail 解析 top_rankings 数组', () {
    final detail = MovieDetail.fromJson({
      'id': 'm1',
      'number': 'SSIS-001',
      'title': '测试影片',
      'cover_url': 'covers/test.jpg',
      'top_rankings': [
        {'ranking': 1, 'title': '全网热播榜', 'top_type': 1},
        {'ranking': 3, 'title': '人气榜', 'top_type': 2},
      ],
    });

    expect(detail.topRankings, hasLength(2));
    expect(detail.topRankings.first.ranking, 1);
    expect(detail.topRankings.first.title, '全网热播榜');
    expect(detail.topRankings.first.topType, 1);
    expect(detail.topRankings.last.ranking, 3);
    expect(detail.topRankings.last.title, '人气榜');
    expect(detail.topRankings.last.topType, 2);
  });

  test('MovieDetail 无 top_rankings 字段时为空列表', () {
    final detail = MovieDetail.fromJson({
      'id': 'm1',
      'number': 'SSIS-001',
      'title': '测试影片',
      'cover_url': 'covers/test.jpg',
    });

    expect(detail.topRankings, isEmpty);
  });
}
