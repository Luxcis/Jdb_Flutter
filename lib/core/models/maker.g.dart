// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maker.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Maker _$MakerFromJson(Map<String, dynamic> json) => Maker(
  id: json['id'] as String,
  name: json['name'] as String,
  avatarUrl: json['avatar_url'] as String?,
  movieCount: (json['movie_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$MakerToJson(Maker instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'avatar_url': instance.avatarUrl,
  'movie_count': instance.movieCount,
};
