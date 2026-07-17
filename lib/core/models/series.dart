import 'package:json_annotation/json_annotation.dart';
part 'series.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Series {
  const Series({required this.id, required this.name, this.movieCount = 0});
  final String id;
  final String name;
  final int movieCount;
  factory Series.fromJson(Map<String, dynamic> json) => _$SeriesFromJson(json);
}
