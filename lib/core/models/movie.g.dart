// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MovieSummary _$MovieSummaryFromJson(Map<String, dynamic> json) => MovieSummary(
  id: json['id'] as String,
  number: json['number'] as String,
  title: json['title'] as String,
  coverUrl: json['cover_url'] as String,
  thumbUrl: json['thumb_url'] as String?,
  releaseDate: json['release_date'] as String?,
  duration: (json['duration'] as num?)?.toInt(),
  score: (json['score'] as num?)?.toDouble(),
);

Map<String, dynamic> _$MovieSummaryToJson(MovieSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'title': instance.title,
      'cover_url': instance.coverUrl,
      'thumb_url': instance.thumbUrl,
      'release_date': instance.releaseDate,
      'duration': instance.duration,
      'score': instance.score,
    };

MovieDetail _$MovieDetailFromJson(Map<String, dynamic> json) => MovieDetail(
  id: json['id'] as String,
  number: json['number'] as String,
  title: json['title'] as String,
  coverUrl: json['cover_url'] as String,
  thumbUrl: json['thumb_url'] as String?,
  releaseDate: json['release_date'] as String?,
  duration: (json['duration'] as num?)?.toInt(),
  score: (json['score'] as num?)?.toDouble(),
  director: json['director'] as String?,
  maker: json['maker'] as String?,
  series: json['series'] as String?,
  actors:
      (json['actors'] as List<dynamic>?)
          ?.map((e) => ActorSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  screenshots:
      (json['screenshots'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  actorMovies:
      (json['actor_movies'] as List<dynamic>?)
          ?.map((e) => MovieSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  relativeMovies:
      (json['relative_movies'] as List<dynamic>?)
          ?.map((e) => MovieSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  magnetCount: (json['magnet_count'] as num?)?.toInt() ?? 0,
  wantWatchCount: (json['want_watch_count'] as num?)?.toInt() ?? 0,
  watchedCount: (json['watched_count'] as num?)?.toInt() ?? 0,
  playable: json['playable'] as bool? ?? false,
  hasSubtitle: json['has_subtitle'] as bool? ?? false,
);

Map<String, dynamic> _$MovieDetailToJson(MovieDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'title': instance.title,
      'cover_url': instance.coverUrl,
      'thumb_url': instance.thumbUrl,
      'release_date': instance.releaseDate,
      'duration': instance.duration,
      'score': instance.score,
      'director': instance.director,
      'maker': instance.maker,
      'series': instance.series,
      'actors': instance.actors,
      'screenshots': instance.screenshots,
      'actor_movies': instance.actorMovies,
      'relative_movies': instance.relativeMovies,
      'tags': instance.tags,
      'magnet_count': instance.magnetCount,
      'want_watch_count': instance.wantWatchCount,
      'watched_count': instance.watchedCount,
      'playable': instance.playable,
      'has_subtitle': instance.hasSubtitle,
    };
