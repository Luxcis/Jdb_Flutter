import 'package:json_annotation/json_annotation.dart';
part 'article.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.title,
    this.coverUrl,
    this.author,
    this.category,
    this.releasedAt,
  });
  final String id;
  final String title;
  final String? coverUrl;
  final String? author;
  final String? category;
  final String? releasedAt;
  factory ArticleSummary.fromJson(Map<String, dynamic> json) =>
      _$ArticleSummaryFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ArticleDetail {
  const ArticleDetail({
    required this.id,
    required this.title,
    this.originName,
    this.originUrl,
    this.coverUrl,
    this.author,
    this.category,
    this.imageDomain,
    this.content,
    this.releasedAt,
  });
  final String id;
  final String title;
  final String? originName;
  final String? originUrl;
  final String? coverUrl;
  final String? author;
  final String? category;
  final String? imageDomain;
  final String? content;
  final String? releasedAt;
  factory ArticleDetail.fromJson(Map<String, dynamic> json) =>
      _$ArticleDetailFromJson(json);
}
