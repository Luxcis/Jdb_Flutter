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

String? apiString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

Map<String, dynamic> normalizeMovieSummaryJson(Map<String, dynamic> json) {
  return {
    ...json,
    if (!json.containsKey('cover_url') && json['thumb_url'] != null)
      'cover_url': json['thumb_url'],
  };
}

Map<String, dynamic> normalizeMovieDetailJson(dynamic data) {
  final root = apiMap(data);
  final movie = apiMap(root['movie']).isNotEmpty ? apiMap(root['movie']) : root;
  final tags = movie['tags'];
  final previewImages = movie['preview_images'];
  return {
    ...normalizeMovieSummaryJson(movie),
    'director': movie['director'] ?? movie['director_name'],
    'maker': movie['maker'] ?? movie['maker_name'],
    'series': movie['series'] ?? movie['series_name'],
    'magnet_count': movie['magnet_count'] ?? movie['magnets_count'],
    'playable': movie['playable'] ?? movie['can_play'],
    'has_subtitle': movie['has_subtitle'] ?? movie['has_cnsub'],
    'screenshots': movie['screenshots'] ?? _imageUrls(previewImages),
    'tags': _tagLabels(tags),
  };
}

Map<String, dynamic> normalizeActorDetailJson(dynamic data) {
  final root = apiMap(data);
  final actor = apiMap(root['actor']).isNotEmpty ? apiMap(root['actor']) : root;
  return {
    ...actor,
    'height': apiString(actor['height']),
    'bust': apiString(actor['bust']),
    'waist': apiString(actor['waist']),
    'hip': apiString(actor['hip'] ?? actor['hips']),
    'movie_count': actor['movie_count'] ?? actor['videos_count'],
  };
}

Map<String, dynamic> normalizeMagnetJson(Map<String, dynamic> json) {
  return {
    ...json,
    'hash': json['hash'] ?? json['id'] ?? '',
    'title': json['title'] ?? json['name'],
    'publish_date': json['publish_date'] ?? json['created_at'],
    'is_high_definition': json['is_high_definition'] ?? json['hd'] != null,
  };
}

Map<String, dynamic> normalizeReviewJson(Map<String, dynamic> json) {
  return {
    ...json,
    'id': apiString(json['id']) ?? '',
    'liked_count': json['liked_count'] ?? json['likes_count'],
    'author': json['author'] ?? {'name': json['username'] ?? ''},
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

List<String> _imageUrls(dynamic images) {
  if (images is List) {
    return images
        .map((image) {
          if (image is String) {
            return image;
          }
          if (image is Map) {
            return apiString(image['url'] ?? image['image_url']);
          }
          return apiString(image);
        })
        .whereType<String>()
        .toList();
  }
  if (images is Map) {
    return images.values
        .expand((value) => value is List ? value : const [])
        .map((image) {
          if (image is String) {
            return image;
          }
          if (image is Map) {
            return apiString(image['url'] ?? image['image_url']);
          }
          return apiString(image);
        })
        .whereType<String>()
        .toList();
  }
  return const [];
}
