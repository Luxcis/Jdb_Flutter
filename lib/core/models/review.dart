import 'package:json_annotation/json_annotation.dart';
part 'review.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ReviewAuthor {
  const ReviewAuthor({required this.name});
  final String name;
  factory ReviewAuthor.fromJson(Map<String, dynamic> json) =>
      _$ReviewAuthorFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Review {
  const Review({
    required this.id,
    this.score,
    this.content,
    this.status,
    this.author,
    this.likedCount = 0,
    this.createdAt,
  });
  final String id;
  final double? score;
  final String? content;
  final String? status;
  final ReviewAuthor? author;
  final int likedCount;
  final String? createdAt;
  factory Review.fromJson(Map<String, dynamic> json) =>
      _$ReviewFromJson(json);
}
