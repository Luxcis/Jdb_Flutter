import 'package:jade/core/models/paged_result.dart';

Map<String, dynamic> apiMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return const {};
}

List<Map<String, dynamic>> apiList(dynamic data, List<String> keys) {
  List? raw;
  if (data is List) {
    raw = data;
  } else if (data is Map) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        raw = value;
        break;
      }
    }
  }
  if (raw == null) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

int apiInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? apiIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? apiDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool apiBool(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => fallback,
    };
  }
  return fallback;
}

String? apiString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

String? _nonEmptyApiString(dynamic value) {
  final text = apiString(value)?.trim();
  return text == null || text.isEmpty ? null : text;
}

Map<String, dynamic> normalizeMovieSummaryJson(Map<String, dynamic> json) {
  return {
    ...json,
    'id': apiString(json['id']) ?? '',
    'number': apiString(json['number']) ?? '',
    'title': apiString(json['title']) ?? '',
    if (!json.containsKey('cover_url') && json['thumb_url'] != null)
      'cover_url': json['thumb_url'],
    'cover_url': apiString(json['cover_url'] ?? json['thumb_url']) ?? '',
    'thumb_url': apiString(json['thumb_url']),
    'duration': apiIntOrNull(json['duration']),
    'score': apiDoubleOrNull(json['score']),
  };
}

Map<String, dynamic> normalizeActorSummaryJson(Map<String, dynamic> json) {
  return {
    ...json,
    'id': apiString(json['id']) ?? '',
    'name':
        _nonEmptyApiString(json['name_zht']) ??
        _nonEmptyApiString(json['name']) ??
        _nonEmptyApiString(json['title']) ??
        '',
    'gender': apiIntOrNull(json['gender']),
    'avatar_url':
        apiString(json['avatar_url'] ?? json['avatar'] ?? json['image_url']) ??
        '',
  };
}

Map<String, dynamic> normalizeMakerJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id']) ?? '',
  'name': apiString(json['name']) ?? '',
  'type': apiInt(json['type'], 0),
  'movie_count': apiInt(
    json['movie_count'] ?? json['movies_count'] ?? json['videos_count'],
    0,
  ),
};

Map<String, dynamic> normalizeDirectorJson(Map<String, dynamic> json) => {
  ...json,
  'id': apiString(json['id']) ?? '',
  'name': apiString(json['name']) ?? '',
  'type': apiInt(json['type'], 0),
  'movie_count': apiInt(
    json['movie_count'] ?? json['movies_count'] ?? json['videos_count'],
    0,
  ),
};

Map<String, dynamic> normalizeMovieDetailJson(dynamic data) {
  final root = apiMap(data);
  final movie = apiMap(root['movie']).isNotEmpty ? apiMap(root['movie']) : root;
  final tags = movie['tags'];
  final previewImages = movie['screenshots'] ?? movie['preview_images'];
  final review = movie['review'];
  final actors = apiList(movie, const [
    'actors',
  ]).map(normalizeActorSummaryJson);
  final actorMovies = apiList(movie, const [
    'actor_movies',
  ]).map(normalizeMovieSummaryJson);
  final relativeMovies = apiList(movie, const [
    'relative_movies',
  ]).map(normalizeMovieSummaryJson);
  return {
    ...normalizeMovieSummaryJson(movie),
    'preview_video_url': _nonEmptyApiString(movie['preview_video_url']),
    'type': apiInt(movie['type'], 0),
    'number_letter': _nonEmptyApiString(movie['number_letter']),
    'director_id': _nonEmptyApiString(movie['director_id']),
    'director': movie['director'] ?? movie['director_name'],
    'maker_id': _nonEmptyApiString(movie['maker_id']),
    'maker': movie['maker'] ?? movie['maker_name'],
    'publisher_id': _nonEmptyApiString(movie['publisher_id']),
    'publisher': movie['publisher'] ?? movie['publisher_name'],
    'series_id': _nonEmptyApiString(movie['series_id']),
    'series': movie['series'] ?? movie['series_name'],
    'magnet_count': apiInt(movie['magnet_count'] ?? movie['magnets_count'], 0),
    'want_watch_count': apiInt(movie['want_watch_count'], 0),
    'watched_count': apiInt(movie['watched_count'], 0),
    'playable': movie['playable'] ?? movie['can_play'],
    'has_subtitle': movie['has_subtitle'] ?? movie['has_cnsub'],
    'screenshots': _imageUrls(previewImages),
    'actors': actors.toList(),
    'actor_movies': actorMovies.toList(),
    'relative_movies': relativeMovies.toList(),
    'tags': _tagLabels(tags),
    'tag_items': _tagItems(tags),
    'top_rankings': apiList(movie, const ['top_rankings'])
        .map(
          (item) => {
            'ranking': apiIntOrNull(item['ranking']),
            'title': apiString(item['title']),
            'top_type': apiIntOrNull(item['top_type']),
          },
        )
        .toList(),
    'review': review is Map
        ? normalizeReviewJson(Map<String, dynamic>.from(review))
        : null,
  };
}

Map<String, dynamic> normalizeActorDetailJson(dynamic data) {
  final root = apiMap(data);
  final actor = apiMap(root['actor']).isNotEmpty ? apiMap(root['actor']) : root;
  return {
    ...normalizeActorSummaryJson(actor),
    'birthday': apiString(actor['birthday']),
    'age': apiIntOrNull(actor['age']),
    'height': apiString(actor['height']),
    'cup': apiString(actor['cup']),
    'bust': apiString(actor['bust']),
    'waist': apiString(actor['waist']),
    'hip': apiString(actor['hip'] ?? actor['hips']),
    'birthplace': apiString(actor['birthplace']),
    'movie_count': apiInt(actor['movie_count'] ?? actor['videos_count'], 0),
    'type': apiIntOrNull(actor['type']),
    'has_collected': apiBool(
      actor['has_collected'] ?? root['has_collected'],
      false,
    ),
    'filter_tags': apiList(root, const ['filter_tags'])
        .map(
          (t) => {
            'id': apiString(t['id']) ?? '',
            'name': apiString(t['name']) ?? '',
            'videos_count': apiInt(t['videos_count'], 0),
          },
        )
        .toList(),
    'tags': apiList(root, const ['tags'])
        .map(
          (t) => {
            'id': apiString(t['id']) ?? '',
            'name': apiString(t['name']) ?? '',
            'videos_count': apiInt(t['videos_count'], 0),
          },
        )
        .toList(),
  };
}

Map<String, dynamic> normalizeMagnetJson(Map<String, dynamic> json) {
  return {
    ...json,
    'hash': apiString(json['hash'] ?? json['id']) ?? '',
    'title': apiString(json['title'] ?? json['name']),
    'size': _magnetSize(json['size']),
    'publish_date': apiString(json['publish_date'] ?? json['created_at']),
    'is_high_definition': apiBool(
      json['is_high_definition'] ?? json['hd'],
      false,
    ),
    'has_subtitle': apiBool(json['has_subtitle'] ?? json['cnsub'], false),
    'files_count': apiInt(json['files_count'], 1),
  };
}

Map<String, dynamic> normalizeListModelJson(Map<String, dynamic> json) {
  return {
    ...json,
    'id': apiString(json['id']) ?? '',
    'name': apiString(json['name'] ?? json['title']) ?? '',
    'movie_count': apiInt(json['movie_count'] ?? json['movies_count'], 0),
    'viewed_count': apiInt(json['viewed_count'] ?? json['views_count'], 0),
    'has_movie': apiBool(json['has_movie'], false),
  };
}

Map<String, dynamic> normalizeReviewJson(Map<String, dynamic> json) {
  final movie = json['movie'];
  return {
    ...json,
    'id': apiString(json['id']) ?? '',
    'liked_count': json['liked_count'] ?? json['likes_count'],
    'liked': apiBool(json['liked'], false),
    'watched_count': apiInt(json['watched_count'], 0),
    'author': json['author'] ?? {'name': json['username'] ?? ''},
    if (movie is Map)
      'movie': {
        ...Map<String, dynamic>.from(movie),
        'id': apiString(movie['id']) ?? '',
        'score': apiString(movie['score']),
      },
  };
}

String? _articleAuthor(dynamic author) {
  if (author is String) return _nonEmptyApiString(author);
  if (author is Map) {
    return _nonEmptyApiString(author['name'] ?? author['username']);
  }
  return _nonEmptyApiString(author);
}

String? _articleCategory(dynamic category) {
  if (category is String) return _nonEmptyApiString(category);
  if (category is Map) return _nonEmptyApiString(category['name']);
  return _nonEmptyApiString(category);
}

Map<String, dynamic> normalizeArticleSummaryJson(Map<String, dynamic> json) {
  return {
    ...json,
    'id': apiString(json['id']) ?? '',
    'title': apiString(json['title']) ?? '',
    'cover_url': apiString(json['cover_url']),
    'author': _articleAuthor(json['author']),
    'category': _articleCategory(json['category']),
    'released_at': apiString(json['released_at']),
  };
}

Map<String, dynamic> normalizeArticleDetailJson(dynamic data) {
  final root = apiMap(data);
  final article = apiMap(root['article']).isNotEmpty
      ? apiMap(root['article'])
      : root;
  return {
    ...normalizeArticleSummaryJson(article),
    'origin_name': apiString(article['origin_name']),
    'origin_url': apiString(article['origin_url']),
    'image_domain': apiString(article['image_domain']),
    'content': apiString(article['content']),
  };
}

List<String> _tagLabels(dynamic tags) {
  if (tags is! List) return const [];
  return tags
      .map((tag) {
        if (tag is String) {
          return tag;
        }
        if (tag is Map) {
          return apiString(tag['name'] ?? tag['title'] ?? tag['value']);
        }
        return apiString(tag);
      })
      .whereType<String>()
      .toList();
}

List<Map<String, dynamic>> _tagItems(dynamic tags) {
  if (tags is! List) return const [];
  return tags.map((tag) {
    if (tag is Map) {
      final name =
          _nonEmptyApiString(tag['name']) ??
          _nonEmptyApiString(tag['title']) ??
          _nonEmptyApiString(tag['value']) ??
          '';
      return {
        'id': apiString(tag['id']) ?? '',
        'name': name,
        'value': apiString(tag['value']) ?? name,
      };
    }
    final name = apiString(tag) ?? '';
    return {'id': '', 'name': name, 'value': name};
  }).toList();
}

List<String> _imageUrls(dynamic images) {
  if (images is List) {
    return images.map(_imageUrl).whereType<String>().toList();
  }
  if (images is Map) {
    return images.values
        .expand((value) => value is List ? value : const [])
        .map(_imageUrl)
        .whereType<String>()
        .toList();
  }
  return const [];
}

String? _imageUrl(dynamic image) {
  if (image is String) return image;
  if (image is Map) {
    return apiString(
      image['large_url'] ??
          image['url'] ??
          image['image_url'] ??
          image['thumb_url'],
    );
  }
  return apiString(image);
}

String? _magnetSize(dynamic value) {
  if (value is! num) return apiString(value);
  final amount = value >= 1024 ? value / 1024 : value;
  final unit = value >= 1024 ? 'GB' : 'MB';
  final digits = amount == amount.roundToDouble() ? 0 : 2;
  return '${amount.toStringAsFixed(digits)} $unit';
}

/// 解析分页响应信封（data 为 BaseEntity.data），统一「无 total_pages 时按满页推断」启发式。
///
/// - [keys]：集合键名列表（如 `['movies', 'items']` 或 `['series']`），按序取第一个存在的数组。
/// - [page]：请求页码，作为 `current_page` 缺失时的回退。
/// - [pageSize]：每页条数，用于「满页则有下一页」推断。
/// - [fromJson]：单条数据的反序列化回调。
PagedResult<T> apiPageResult<T>(
  dynamic data, {
  required List<String> keys,
  required int page,
  required int pageSize,
  required T Function(Map<String, dynamic>) fromJson,
}) {
  final map = apiMap(data);
  final items = apiList(map, keys).map(fromJson).toList(growable: false);
  final currentPage = apiInt(map['current_page'], page);
  final totalPages = map['total_pages'] == null
      ? currentPage + (items.length >= pageSize ? 1 : 0)
      : apiInt(map['total_pages'], currentPage);
  return PagedResult(
    items: items,
    currentPage: currentPage,
    totalPages: totalPages,
    total: apiInt(map['total_count'] ?? map['total'], items.length),
  );
}
