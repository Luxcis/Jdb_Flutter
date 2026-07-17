import 'package:json_annotation/json_annotation.dart';
part 'magnet.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Magnet {
  const Magnet({
    required this.hash,
    this.title,
    this.size,
    this.publishDate,
    this.isHighDefinition = false,
  });
  final String hash;
  final String? title;
  final String? size;
  final String? publishDate;
  final bool isHighDefinition;
  factory Magnet.fromJson(Map<String, dynamic> json) =>
      _$MagnetFromJson(json);
}
