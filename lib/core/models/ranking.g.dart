// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ranking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RankingEntry _$RankingEntryFromJson(Map<String, dynamic> json) => RankingEntry(
  rank: (json['rank'] as num).toInt(),
  movie: MovieSummary.fromJson(json['movie'] as Map<String, dynamic>),
);
