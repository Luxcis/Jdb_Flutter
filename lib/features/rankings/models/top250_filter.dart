import 'package:flutter/foundation.dart';

/// Top250 筛选条件。
@immutable
class Top250Filter {
  const Top250Filter({
    this.type = 'all',
    this.typeValue = '',
    this.startRank = 1,
    this.ignoreWatched = false,
  });

  final String type;
  final String typeValue;
  final int startRank;
  final bool ignoreWatched;

  Top250Filter copyWith({
    String? type,
    String? typeValue,
    int? startRank,
    bool? ignoreWatched,
  }) {
    return Top250Filter(
      type: type ?? this.type,
      typeValue: typeValue ?? this.typeValue,
      startRank: startRank ?? this.startRank,
      ignoreWatched: ignoreWatched ?? this.ignoreWatched,
    );
  }
}
