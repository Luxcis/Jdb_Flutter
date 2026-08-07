import 'package:json_annotation/json_annotation.dart';
part 'review.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ReviewAuthor {
  const ReviewAuthor({required this.name});
  final String name;
  factory ReviewAuthor.fromJson(Map<String, dynamic> json) =>
      _$ReviewAuthorFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ReviewMovie {
  const ReviewMovie({
    required this.id,
    this.number,
    this.title,
    this.originTitle,
    this.score,
    this.thumbUrl,
    this.releaseDate,
  });

  final String id;
  final String? number;
  final String? title;
  final String? originTitle;
  final String? score;
  final String? thumbUrl;
  final String? releaseDate;

  factory ReviewMovie.fromJson(Map<String, dynamic> json) =>
      _$ReviewMovieFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Review {
  const Review({
    required this.id,
    this.score,
    this.content,
    this.status,
    this.author,
    this.likedCount = 0,
    this.watchedCount = 0,
    this.createdAt,
    this.movie,
  });
  final String id;
  final double? score;
  final String? content;
  final String? status;
  final ReviewAuthor? author;
  final int likedCount;
  final int watchedCount;
  final String? createdAt;
  final ReviewMovie? movie;
  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);
}
