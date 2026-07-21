import 'package:json_annotation/json_annotation.dart';
part 'article.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Article {
  const Article({required this.id, required this.title, this.coverUrl, this.publishDate});
  final String id;
  final String title;
  final String? coverUrl;
  final String? publishDate;
  factory Article.fromJson(Map<String, dynamic> json) => _$ArticleFromJson(json);
}
