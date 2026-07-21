// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListModel _$ListModelFromJson(Map<String, dynamic> json) => ListModel(
  id: json['id'] as String,
  name: json['name'] as String,
  movieCount: (json['movie_count'] as num?)?.toInt() ?? 0,
  viewedCount: (json['viewed_count'] as num?)?.toInt() ?? 0,
);
