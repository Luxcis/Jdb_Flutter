import 'package:json_annotation/json_annotation.dart';
part 'director.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Director {
  const Director({required this.id, required this.name, this.avatarUrl, this.movieCount = 0});
  final String id;
  final String name;
  final String? avatarUrl;
  final int movieCount;
  factory Director.fromJson(Map<String, dynamic> json) => _$DirectorFromJson(json);
}
