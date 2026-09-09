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
    this.hasCollected = false,
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

  /// 当前用户是否已收藏该演员（来自详情接口 `has_collected`）。
  final bool hasCollected;
  final List<ActorTagItem> filterTags;
  final List<ActorTagItem> tags;
  factory ActorDetail.fromJson(Map<String, dynamic> json) =>
      _$ActorDetailFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$ActorDetailToJson(this);

  /// 不要用 `fromJson(toJson())` 复制实例：生成的 toJson 对 `filter_tags`/
  /// `tags` 直接输出 `ActorTagItem` 对象而非 Map，往返会触发类型转换异常。
  ActorDetail copyWith({bool? hasCollected}) {
    return ActorDetail(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      gender: gender,
      hasCollected: hasCollected ?? this.hasCollected,
      birthday: birthday,
      age: age,
      height: height,
      cup: cup,
      bust: bust,
      waist: waist,
      hip: hip,
      birthplace: birthplace,
      movieCount: movieCount,
      type: type,
      filterTags: filterTags,
      tags: tags,
    );
  }
}
