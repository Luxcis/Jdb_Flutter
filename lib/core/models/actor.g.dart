// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActorSummary _$ActorSummaryFromJson(Map<String, dynamic> json) => ActorSummary(
  id: json['id'] as String,
  name: json['name'] as String,
  avatarUrl: json['avatar_url'] as String,
  gender: json['gender'] as String?,
);

Map<String, dynamic> _$ActorSummaryToJson(ActorSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatar_url': instance.avatarUrl,
      'gender': instance.gender,
    };

ActorDetail _$ActorDetailFromJson(Map<String, dynamic> json) => ActorDetail(
  id: json['id'] as String,
  name: json['name'] as String,
  avatarUrl: json['avatar_url'] as String,
  gender: json['gender'] as String?,
  birthday: json['birthday'] as String?,
  age: (json['age'] as num?)?.toInt(),
  height: json['height'] as String?,
  cup: json['cup'] as String?,
  bust: json['bust'] as String?,
  waist: json['waist'] as String?,
  hip: json['hip'] as String?,
  birthplace: json['birthplace'] as String?,
  movieCount: (json['movie_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ActorDetailToJson(ActorDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatar_url': instance.avatarUrl,
      'gender': instance.gender,
      'birthday': instance.birthday,
      'age': instance.age,
      'height': instance.height,
      'cup': instance.cup,
      'bust': instance.bust,
      'waist': instance.waist,
      'hip': instance.hip,
      'birthplace': instance.birthplace,
      'movie_count': instance.movieCount,
    };
