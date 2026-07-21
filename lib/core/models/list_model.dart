import 'package:json_annotation/json_annotation.dart';
part 'list_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class ListModel {
  const ListModel({required this.id, required this.name, this.movieCount = 0, this.viewedCount = 0});
  final String id;
  final String name;
  final int movieCount;
  final int viewedCount;
  factory ListModel.fromJson(Map<String, dynamic> json) => _$ListModelFromJson(json);
}
