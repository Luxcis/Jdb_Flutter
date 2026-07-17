import 'package:json_annotation/json_annotation.dart';
part 'tag.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Tag {
  const Tag({required this.id, required this.name, this.value});
  final String id;
  final String name;
  final String value;
  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);
}
