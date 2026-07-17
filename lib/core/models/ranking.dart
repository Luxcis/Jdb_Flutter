import 'package:jade/core/models/movie.dart';
import 'package:json_annotation/json_annotation.dart';
part 'ranking.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class RankingEntry {
  const RankingEntry({required this.rank, required this.movie});
  final int rank;
  final MovieSummary movie;
  factory RankingEntry.fromJson(Map<String, dynamic> json) =>
      _$RankingEntryFromJson(json);
}
