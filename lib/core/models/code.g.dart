// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'code.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Code _$CodeFromJson(Map<String, dynamic> json) => Code(
  id: json['id'] as String,
  number: json['number'] as String,
  movieCount: (json['movie_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CodeToJson(Code instance) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'movie_count': instance.movieCount,
};
