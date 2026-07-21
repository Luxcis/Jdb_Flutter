import 'package:json_annotation/json_annotation.dart';
part 'paged_result.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, genericArgumentFactories: true, createToJson: false)
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.total,
  });
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int total;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) => _$PagedResultFromJson(json, fromJsonT);
}
