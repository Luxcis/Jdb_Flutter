import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/features/articles/models/article.dart';

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

  test('normalizeActorSummaryJson 保留演员性别', () {
    final actor = ActorSummary.fromJson(
      normalizeActorSummaryJson({
        'id': 'a1',
        'name': '演员',
        'avatar_url': '',
        'gender': 1,
      }),
    );

    expect(actor.gender, 1);
  });

  test('normalizeActorSummaryJson 优先使用非空 name_zht', () {
    final actor = ActorSummary.fromJson(
      normalizeActorSummaryJson({
        'id': 'a1',
        'name': '日本語名',
        'name_zht': '繁體中文名',
        'avatar_url': '',
      }),
    );

    expect(actor.name, '繁體中文名');
  });

  test('normalizeActorSummaryJson 在 name_zht 为空时回退到 name', () {
    final actor = ActorSummary.fromJson(
      normalizeActorSummaryJson({
        'id': 'a1',
        'name': '日本語名',
        'name_zht': '   ',
        'avatar_url': '',
      }),
    );

    expect(actor.name, '日本語名');
  });

  test('normalizeMakerJson 将 videos_count 映射为 movieCount 并保留 type', () {
    final maker = Maker.fromJson(
      normalizeMakerJson({
        'id': 'xZyO',
        'type': 1,
        'name': 'Heydouga',
        'videos_count': 25645,
      }),
    );

    expect(maker.id, 'xZyO');
    expect(maker.name, 'Heydouga');
    expect(maker.type, 1);
    expect(maker.movieCount, 25645);
  });

  test('normalizeMakerJson 为缺失字段提供兜底值', () {
    final maker = Maker.fromJson(normalizeMakerJson({'id': null}));

    expect(maker.id, '');
    expect(maker.name, '');
    expect(maker.type, 0);
    expect(maker.movieCount, 0);
  });

  test('normalizeDirectorJson 将 videos_count 映射为 movieCount 并保留 type', () {
    final director = Director.fromJson(
      normalizeDirectorJson({
        'id': 'AqK',
        'type': '0',
        'name': 'K太郎',
        'videos_count': 3122,
      }),
    );

    expect(director.id, 'AqK');
    expect(director.name, 'K太郎');
    expect(director.type, 0);
    expect(director.movieCount, 3122);
  });

  test('normalizeDirectorJson 为缺失字段提供兜底值', () {
    final director = Director.fromJson(normalizeDirectorJson({'id': null}));

    expect(director.id, '');
    expect(director.name, '');
    expect(director.type, 0);
    expect(director.movieCount, 0);
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

  test('normalizeMovieDetailJson 将 top_rankings 的字符串数值转为数字', () {
    final movie = MovieDetail.fromJson(
      normalizeMovieDetailJson({
        'movie': {
          'id': 'm1',
          'number': 'ABC-001',
          'title': 'Title',
          'cover_url': 'cover.jpg',
          'top_rankings': [
            {'ranking': '1', 'title': '全网热播榜', 'top_type': '2'},
            {'ranking': 3, 'title': null, 'top_type': null},
          ],
        },
      }),
    );

    expect(movie.topRankings, hasLength(2));
    expect(movie.topRankings[0].ranking, 1);
    expect(movie.topRankings[0].title, '全网热播榜');
    expect(movie.topRankings[0].topType, 2);
    expect(movie.topRankings[1].ranking, 3);
    expect(movie.topRankings[1].title, isNull);
    expect(movie.topRankings[1].topType, isNull);
  });

  test('normalizeMovieDetailJson 解析并清理预告片地址', () {
    final movie = MovieDetail.fromJson(
      normalizeMovieDetailJson({
        'movie': {
          'id': 'm1',
          'number': 'ABC-001',
          'title': 'Title',
          'cover_url': 'cover.jpg',
          'preview_video_url':
              '  https://media.example.com/preview.m3u8?token=a  ',
        },
      }),
    );

    expect(
      movie.previewVideoUrl,
      'https://media.example.com/preview.m3u8?token=a',
    );
  });

  test('normalizeMovieDetailJson 将缺失或空白预告片地址归一化为 null', () {
    for (final raw in <Object?>[null, '', '   ']) {
      final movie = MovieDetail.fromJson(
        normalizeMovieDetailJson({
          'movie': {
            'id': 'm1',
            'number': 'ABC-001',
            'title': 'Title',
            'cover_url': 'cover.jpg',
            'preview_video_url': ?raw,
          },
        }),
      );

      expect(movie.previewVideoUrl, isNull, reason: 'raw=$raw');
    }
  });

  test('normalizeMovieDetailJson 解析当前用户影评并统一数字 ID', () {
    final movie = MovieDetail.fromJson(
      normalizeMovieDetailJson({
        'movie': {
          'id': 'm1',
          'number': 'ABC-001',
          'title': 'Title',
          'cover_url': '',
          'review': {
            'id': 245236128,
            'status': 'watched',
            'score': 3,
            'content': '评论内容',
          },
        },
      }),
    );

    expect(movie.review?.id, '245236128');
    expect(movie.review?.status, 'watched');
    expect(movie.review?.score, 3);
    expect(movie.review?.content, '评论内容');
  });

  test('normalizeMovieDetailJson 将缺失或 null review 解析为 null', () {
    for (final review in <Object?>[null, const _AbsentReview()]) {
      final json = <String, dynamic>{
        'id': 'm1',
        'number': 'ABC-001',
        'title': 'Title',
        'cover_url': '',
      };
      if (review is! _AbsentReview) json['review'] = review;

      final movie = MovieDetail.fromJson(normalizeMovieDetailJson(json));

      expect(movie.review, isNull);
    }
  });

  test('normalizeMovieDetailJson 保留基础信息跳转所需的 OpenAPI 字段', () {
    final movie = MovieDetail.fromJson(
      normalizeMovieDetailJson({
        'movie': {
          'id': 'm1',
          'type': '2',
          'number': 'TEST-001',
          'number_letter': 'TEST',
          'title': 'Title',
          'cover_url': 'cover.jpg',
          'director_id': 'director-1',
          'director_name': '测试&导演',
          'maker_id': 'maker-1',
          'maker_name': '测试片商',
          'publisher_id': 'publisher-1',
          'publisher_name': '测试发行商',
          'series_id': 'series-1',
          'series_name': '测试系列',
          'tags': [
            {'id': 'tag-1', 'name': '剧情', 'value': 'plot'},
            '中文字幕',
          ],
        },
      }),
    );

    expect(movie.type, 2);
    expect(movie.numberLetter, 'TEST');
    expect(movie.directorId, 'director-1');
    expect(movie.director, '测试&导演');
    expect(movie.makerId, 'maker-1');
    expect(movie.maker, '测试片商');
    expect(movie.publisherId, 'publisher-1');
    expect(movie.publisher, '测试发行商');
    expect(movie.seriesId, 'series-1');
    expect(movie.series, '测试系列');
    expect(movie.tags, ['剧情', '中文字幕']);
    expect(movie.tagItems, hasLength(2));
    expect(movie.tagItems.first.id, 'tag-1');
    expect(movie.tagItems.first.name, '剧情');
    expect(movie.tagItems.first.value, 'plot');
    expect(movie.tagItems.last.id, '');
    expect(movie.tagItems.last.name, '中文字幕');
    expect(movie.tagItems.last.value, '中文字幕');
  });

  test('normalizeMovieDetailJson 为缺失的基础信息跳转字段提供兼容默认值', () {
    final movie = MovieDetail.fromJson(
      normalizeMovieDetailJson({
        'id': 'm1',
        'number': 'TEST-001',
        'title': 'Title',
        'cover_url': 'cover.jpg',
      }),
    );

    expect(movie.type, 0);
    expect(movie.numberLetter, isNull);
    expect(movie.directorId, isNull);
    expect(movie.makerId, isNull);
    expect(movie.publisherId, isNull);
    expect(movie.seriesId, isNull);
    expect(movie.tagItems, isEmpty);
  });

  test('normalizeMovieDetailJson 解析内嵌剧照和两类关联影片', () {
    final movie = MovieDetail.fromJson(
      normalizeMovieDetailJson({
        'movie': {
          'id': 'm1',
          'number': 'ABC-001',
          'title': 'Title',
          'cover_url': 'cover.jpg',
          'preview_images': {
            'sample': [
              {'url': 'screenshots/one.jpg'},
              'screenshots/two.jpg',
            ],
          },
          'actor_movies': [
            {
              'id': 'actor-movie',
              'number': 'ACT-001',
              'title': 'Actor Movie',
              'thumb_url': 'thumbs/actor.jpg',
            },
          ],
          'relative_movies': [
            {
              'id': 'relative-movie',
              'number': 'REL-001',
              'title': 'Relative Movie',
              'cover_url': 'covers/relative.jpg',
            },
          ],
        },
      }),
    );

    expect(movie.screenshots, ['screenshots/one.jpg', 'screenshots/two.jpg']);
    expect(movie.actorMovies.single.id, 'actor-movie');
    expect(movie.actorMovies.single.thumbUrl, 'thumbs/actor.jpg');
    expect(movie.relativeMovies.single.id, 'relative-movie');
  });

  test('normalizeMovieDetailJson 优先使用真实剧照 large_url', () {
    final movie = MovieDetail.fromJson(
      normalizeMovieDetailJson({
        'movie': {
          'id': 'm1',
          'number': 'ABC-001',
          'title': 'Title',
          'cover_url': 'cover.jpg',
          'preview_images': [
            {
              'large_url': 'screenshots/large.jpg',
              'thumb_url': 'screenshots/thumb.jpg',
            },
          ],
        },
      }),
    );

    expect(movie.screenshots, ['screenshots/large.jpg']);
  });

  test('normalizeMagnetJson 兼容真实数字大小和布尔高清字段', () {
    final magnet = Magnet.fromJson(
      normalizeMagnetJson({
        'name': 'movie.torrent',
        'hash': 'hash-1',
        'size': 9910,
        'hd': false,
        'created_at': '2026-07-22',
      }),
    );

    expect(magnet.title, 'movie.torrent');
    expect(magnet.size, '9.68 GB');
    expect(magnet.publishDate, '2026-07-22');
    expect(magnet.isHighDefinition, isFalse);
  });

  group('normalizeArticleSummaryJson', () {
    test('author 支持字符串/对象/缺失三种形态', () {
      expect(
        normalizeArticleSummaryJson({
          'id': 1,
          'title': 't',
          'author': '作者',
        })['author'],
        '作者',
      );
      expect(
        normalizeArticleSummaryJson({
          'id': 1,
          'title': 't',
          'author': {'name': '作者'},
        })['author'],
        '作者',
      );
      expect(
        normalizeArticleSummaryJson({'id': 1, 'title': 't'})['author'],
        isNull,
      );
    });

    test('id 归一化为字符串，空 category 归一化为 null', () {
      final json = normalizeArticleSummaryJson({
        'id': 123,
        'title': '标题',
        'category': '  ',
      });
      expect(json['id'], '123');
      expect(json['category'], isNull);
      expect(json['cover_url'], isNull);
    });

    test('category 为 {id, name} 对象时提取 name', () {
      final json = normalizeArticleSummaryJson({
        'id': 1,
        'title': 't',
        'category': {'id': 1, 'name': '發片'},
      });

      expect(json['category'], '發片');
    });
  });

  group('normalizeArticleDetailJson', () {
    test('{article: ...} wrapper 展开并解析新字段', () {
      final detail = ArticleDetail.fromJson(
        normalizeArticleDetailJson({
          'article': {
            'id': 1,
            'title': '标题',
            'origin_name': '原题名',
            'origin_url': 'https://origin.example.com/post/1',
            'cover_url': 'cover.jpg',
            'author': {'username': '作者U'},
            'category': '业界',
            'image_domain': 'https://img.example.com',
            'content': '<p>正文</p>',
            'released_at': '2026-08-05',
          },
        }),
      );

      expect(detail.id, '1');
      expect(detail.title, '标题');
      expect(detail.originName, '原题名');
      expect(detail.originUrl, 'https://origin.example.com/post/1');
      expect(detail.coverUrl, 'cover.jpg');
      expect(detail.author, '作者U');
      expect(detail.category, '业界');
      expect(detail.imageDomain, 'https://img.example.com');
      expect(detail.content, '<p>正文</p>');
      expect(detail.releasedAt, '2026-08-05');
    });

    test('无 wrapper 时直接使用根字段，缺失字段为 null', () {
      final json = normalizeArticleDetailJson({'id': 2, 'title': '标题2'});

      expect(json['origin_name'], isNull);
      expect(json['origin_url'], isNull);
      expect(json['image_domain'], isNull);
      expect(json['content'], isNull);
    });
  });

  group('apiPageResult', () {
    test('正常解析：逐字段透传并按序取第一个存在的集合键', () {
      final result = apiPageResult(
        {
          'movies': [
            {'name': 'M1'},
            {'name': 'M2'},
          ],
          'items': [
            {'name': 'X1'},
          ],
          'current_page': 3,
          'total_pages': 10,
          'total_count': 500,
        },
        keys: const ['movies', 'items'],
        page: 1,
        pageSize: 48,
        fromJson: (j) => j['name'] as String,
      );

      expect(result.items, ['M1', 'M2']);
      expect(result.currentPage, 3);
      expect(result.totalPages, 10);
      expect(result.total, 500);
    });

    test('无 total_pages 且满页时 totalPages 为 currentPage + 1', () {
      final result = apiPageResult(
        {
          'movies': List.generate(48, (i) => {'name': 'M$i'}),
          'current_page': 2,
        },
        keys: const ['movies', 'items'],
        page: 2,
        pageSize: 48,
        fromJson: (j) => j['name'] as String,
      );

      expect(result.totalPages, 3);
    });

    test('无 total_pages 且不满页时 totalPages 为 currentPage', () {
      final result = apiPageResult(
        {
          'movies': List.generate(10, (i) => {'name': 'M$i'}),
          'current_page': 2,
        },
        keys: const ['movies', 'items'],
        page: 2,
        pageSize: 48,
        fromJson: (j) => j['name'] as String,
      );

      expect(result.totalPages, 2);
    });

    test('current_page 与 total 缺失时回退到 page 与 items.length', () {
      final result = apiPageResult(
        {
          'movies': [
            {'name': 'M1'},
          ],
        },
        keys: const ['movies'],
        page: 7,
        pageSize: 48,
        fromJson: (j) => j['name'] as String,
      );

      expect(result.currentPage, 7);
      expect(result.totalPages, 7);
      expect(result.total, 1);
    });
  });
}

class _AbsentReview {
  const _AbsentReview();
}
