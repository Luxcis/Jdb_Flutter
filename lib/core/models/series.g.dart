// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Series _$SeriesFromJson(Map<String, dynamic> json) => Series(
  id: json['id'] as String,
  name: json['name'] as String,
  movieCount: (json['movie_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SeriesToJson(Series instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'movie_count': instance.movieCount,
};
