// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReviewAuthor _$ReviewAuthorFromJson(Map<String, dynamic> json) =>
    ReviewAuthor(name: json['name'] as String);

Map<String, dynamic> _$ReviewAuthorToJson(ReviewAuthor instance) =>
    <String, dynamic>{'name': instance.name};

Review _$ReviewFromJson(Map<String, dynamic> json) => Review(
  id: json['id'] as String,
  score: (json['score'] as num?)?.toDouble(),
  content: json['content'] as String?,
  status: json['status'] as String?,
  author: json['author'] == null
      ? null
      : ReviewAuthor.fromJson(json['author'] as Map<String, dynamic>),
  likedCount: (json['liked_count'] as num?)?.toInt() ?? 0,
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$ReviewToJson(Review instance) => <String, dynamic>{
  'id': instance.id,
  'score': instance.score,
  'content': instance.content,
  'status': instance.status,
  'author': instance.author,
  'liked_count': instance.likedCount,
  'created_at': instance.createdAt,
};
