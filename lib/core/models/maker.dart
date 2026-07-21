import 'package:json_annotation/json_annotation.dart';
part 'maker.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Maker {
  const Maker({required this.id, required this.name, this.avatarUrl, this.movieCount = 0});
  final String id;
  final String name;
  final String? avatarUrl;
  final int movieCount;
  factory Maker.fromJson(Map<String, dynamic> json) => _$MakerFromJson(json);
}
