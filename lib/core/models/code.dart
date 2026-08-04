import 'package:json_annotation/json_annotation.dart';
part 'code.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Code {
  const Code({required this.id, required this.number, this.movieCount = 0, this.type = 0});
  final String id;
  final String number;
  final int movieCount;
  final int type;
  factory Code.fromJson(Map<String, dynamic> json) => _$CodeFromJson(json);
}
