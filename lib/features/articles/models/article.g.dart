// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'article.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArticleSummary _$ArticleSummaryFromJson(Map<String, dynamic> json) =>
    ArticleSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      author: json['author'] as String?,
      category: json['category'] as String?,
      releasedAt: json['released_at'] as String?,
    );

ArticleDetail _$ArticleDetailFromJson(Map<String, dynamic> json) =>
    ArticleDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      originName: json['origin_name'] as String?,
      originUrl: json['origin_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      author: json['author'] as String?,
      category: json['category'] as String?,
      imageDomain: json['image_domain'] as String?,
      content: json['content'] as String?,
      releasedAt: json['released_at'] as String?,
    );
