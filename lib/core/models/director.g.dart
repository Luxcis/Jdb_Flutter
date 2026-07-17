// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'director.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Director _$DirectorFromJson(Map<String, dynamic> json) => Director(
  id: json['id'] as String,
  name: json['name'] as String,
  avatarUrl: json['avatar_url'] as String?,
  movieCount: (json['movie_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$DirectorToJson(Director instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'avatar_url': instance.avatarUrl,
  'movie_count': instance.movieCount,
};
