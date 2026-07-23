import 'package:json_annotation/json_annotation.dart';
part 'magnet.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class Magnet {
  const Magnet({
    required this.hash,
    this.title,
    this.size,
    this.publishDate,
    this.isHighDefinition = false,
    this.hasSubtitle = false,
    this.filesCount = 1,
  });
  final String hash;
  final String? title;
  final String? size;
  final String? publishDate;
  final bool isHighDefinition;
  final bool hasSubtitle;
  final int filesCount;
  factory Magnet.fromJson(Map<String, dynamic> json) => _$MagnetFromJson(json);
}
