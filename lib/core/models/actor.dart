import 'package:json_annotation/json_annotation.dart';
part 'actor.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ActorSummary {
  const ActorSummary({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.gender,
  });
  final String id;
  final String name;
  final String avatarUrl;
  final String? gender;
  factory ActorSummary.fromJson(Map<String, dynamic> json) =>
      _$ActorSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$ActorSummaryToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ActorDetail extends ActorSummary {
  const ActorDetail({
    required super.id,
    required super.name,
    required super.avatarUrl,
    super.gender,
    this.birthday,
    this.age,
    this.height,
    this.cup,
    this.bust,
    this.waist,
    this.hip,
    this.birthplace,
    this.movieCount = 0,
  });
  final String? birthday;
  final int? age;
  final String? height;
  final String? cup;
  final String? bust;
  final String? waist;
  final String? hip;
  final String? birthplace;
  final int movieCount;
  factory ActorDetail.fromJson(Map<String, dynamic> json) =>
      _$ActorDetailFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$ActorDetailToJson(this);
}
