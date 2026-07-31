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
  final int? gender;
  factory ActorSummary.fromJson(Map<String, dynamic> json) =>
      _$ActorSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$ActorSummaryToJson(this);
}

/// 演员标签项，用于演员详情页的影片筛选。
class ActorTagItem {
  const ActorTagItem({
    required this.id,
    required this.name,
    required this.videosCount,
  });

  /// 标签 ID，用于拼装 filter_by_tags 参数。
  final String id;

  /// 标签显示名称。
  final String name;

  /// 该标签关联的影片数量。
  final int videosCount;

  factory ActorTagItem.fromJson(Map<String, dynamic> json) {
    return ActorTagItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      videosCount: (json['videos_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'videos_count': videosCount,
    };
  }
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
    this.type,
    this.filterTags = const [],
    this.tags = const [],
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
  final int? type;
  final List<ActorTagItem> filterTags;
  final List<ActorTagItem> tags;
  factory ActorDetail.fromJson(Map<String, dynamic> json) =>
      _$ActorDetailFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$ActorDetailToJson(this);
}
