import 'package:json_annotation/json_annotation.dart';
part 'list_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ListModel {
  const ListModel({
    required this.id,
    required this.name,
    this.movieCount = 0,
    this.viewedCount = 0,
    this.hasMovie = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final int movieCount;
  final int viewedCount;
  final bool hasMovie;

  /// 创建时间（来自 `created_at`），可能为 null。
  final String? createdAt;

  ListModel copyWith({int? movieCount, bool? hasMovie}) {
    return ListModel(
      id: id,
      name: name,
      movieCount: movieCount ?? this.movieCount,
      viewedCount: viewedCount,
      hasMovie: hasMovie ?? this.hasMovie,
      createdAt: createdAt,
    );
  }

  factory ListModel.fromJson(Map<String, dynamic> json) =>
      _$ListModelFromJson(json);
}
