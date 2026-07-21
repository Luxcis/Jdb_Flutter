import 'package:jade/core/models/actor.dart';
import 'package:json_annotation/json_annotation.dart';
part 'movie.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class MovieSummary {
  const MovieSummary({
    required this.id,
    required this.number,
    required this.title,
    required this.coverUrl,
    this.thumbUrl,
    this.releaseDate,
    this.duration,
    this.score,
  });
  final String id;
  final String number;
  final String title;
  final String coverUrl;
  final String? thumbUrl;
  final String? releaseDate;
  final int? duration;
  final double? score;
  factory MovieSummary.fromJson(Map<String, dynamic> json) =>
      _$MovieSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$MovieSummaryToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MovieDetail extends MovieSummary {
  const MovieDetail({
    required super.id,
    required super.number,
    required super.title,
    required super.coverUrl,
    super.thumbUrl,
    super.releaseDate,
    super.duration,
    super.score,
    this.director,
    this.maker,
    this.series,
    this.actors = const [],
    this.screenshots = const [],
    this.tags = const [],
    this.magnetCount = 0,
    this.wantWatchCount = 0,
    this.watchedCount = 0,
    this.playable = false,
    this.hasSubtitle = false,
  });
  final String? director;
  final String? maker;
  final String? series;
  final List<ActorSummary> actors;
  final List<String> screenshots;
  final List<String> tags;
  final int magnetCount;
  final int wantWatchCount;
  final int watchedCount;
  final bool playable;
  final bool hasSubtitle;
  factory MovieDetail.fromJson(Map<String, dynamic> json) =>
      _$MovieDetailFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$MovieDetailToJson(this);
}
