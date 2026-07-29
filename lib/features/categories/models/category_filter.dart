import 'dart:collection';

import 'package:flutter/foundation.dart';

enum CategorySort {
  release('发布日期', 'release'),
  update('更新时间', 'update'),
  score('评分', 'score'),
  hit('热度', 'hit'),
  wantWatch('想看人数', 'want_watch_count'),
  watched('看过人数', 'watched_count');

  const CategorySort(this.label, this.value);

  final String label;
  final String value;
}

@immutable
class CategoryFilter {
  CategoryFilter({
    this.main,
    this.year,
    this.duration,
    this.month,
    Map<String, Set<String>> extraByCategory = const {},
    this.sort = CategorySort.release,
    this.orderBy = 'desc',
  }) : extraByCategory = _immutableExtras(extraByCategory);

  final String? main;
  final String? year;
  final String? duration;
  final String? month;
  final Map<String, Set<String>> extraByCategory;
  final CategorySort sort;
  final String orderBy;

  static Map<String, Set<String>> _immutableExtras(
    Map<String, Set<String>> extras,
  ) => Map.unmodifiable({
    for (final entry in extras.entries)
      entry.key: Set.unmodifiable(LinkedHashSet<String>.of(entry.value)),
  });

  Set<String> selectedValues(String categoryId) {
    final single = switch (categoryId) {
      'main' => main,
      'year' => year,
      'duration' => duration,
      'month' => month,
      _ => null,
    };
    if (single != null) return {single};
    return Set.unmodifiable(extraByCategory[categoryId] ?? const {});
  }

  CategoryFilter toggle(String categoryId, String value) {
    if (const {'main', 'year', 'duration', 'month'}.contains(categoryId)) {
      final selected = selectedValues(categoryId);
      final current = selected.isEmpty ? null : selected.first;
      return _copySingle(categoryId, current == value ? null : value);
    }
    final extras = {
      for (final entry in extraByCategory.entries)
        entry.key: LinkedHashSet<String>.of(entry.value),
    };
    final values = extras.putIfAbsent(categoryId, LinkedHashSet.new);
    values.contains(value) ? values.remove(value) : values.add(value);
    if (values.isEmpty) extras.remove(categoryId);
    return copyWith(extraByCategory: extras);
  }

  CategoryFilter _copySingle(String categoryId, String? value) =>
      CategoryFilter(
        main: categoryId == 'main' ? value : main,
        year: categoryId == 'year' ? value : year,
        duration: categoryId == 'duration' ? value : duration,
        month: categoryId == 'month' ? value : month,
        extraByCategory: extraByCategory,
        sort: sort,
        orderBy: orderBy,
      );

  CategoryFilter copyWith({
    Map<String, Set<String>>? extraByCategory,
    CategorySort? sort,
    String? orderBy,
  }) => CategoryFilter(
    main: main,
    year: year,
    duration: duration,
    month: month,
    extraByCategory: extraByCategory ?? this.extraByCategory,
    sort: sort ?? this.sort,
    orderBy: orderBy ?? this.orderBy,
  );

  String toFilterBy(int type, List<String> categoryOrder) {
    if (type < 0 || type > 4) {
      throw RangeError.range(type, 0, 4, 'type');
    }
    final extras = LinkedHashSet<String>();
    for (final categoryId in categoryOrder) {
      extras.addAll(extraByCategory[categoryId] ?? const {});
    }
    return [
      '$type',
      't',
      main ?? '',
      extras.join(','),
      year ?? '',
      duration ?? '',
      month ?? '',
    ].join(':');
  }
}
