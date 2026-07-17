import 'package:json_annotation/json_annotation.dart';
part 'publisher.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Publisher {
  const Publisher({required this.id, required this.name, this.avatarUrl, this.movieCount = 0});
  final String id;
  final String name;
  final String? avatarUrl;
  final int movieCount;
  factory Publisher.fromJson(Map<String, dynamic> json) => _$PublisherFromJson(json);
}
