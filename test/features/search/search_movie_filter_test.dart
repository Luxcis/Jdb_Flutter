import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';

void main() {
  test('影片搜索筛选提供完整标签与接口值映射', () {
    expect(SearchMovieType.values.map((value) => (value.label, value.value)), [
      ('全部', 'all'),
      ('有码', '0'),
      ('无码', '1'),
      ('欧美', '2'),
      ('FC2', '3'),
      ('动漫', '4'),
    ]);
    expect(
      SearchMovieAvailability.values.map((value) => (value.label, value.value)),
      [
        ('全部', 'all'),
        ('可播放', 'can_play'),
        ('含磁链', 'magnets'),
        ('字幕', 'subtitle'),
        ('单体', 'single'),
      ],
    );
    expect(SearchMovieSort.values.map((value) => (value.label, value.value)), [
      ('相关度', 'relevance'),
      ('发布时间', 'release'),
      ('更新时间', 'update'),
      ('评分', 'score'),
    ]);
  });

  test('默认筛选组合及 copyWith 保持不可变语义', () {
    const original = SearchMovieFilter();
    final changed = original.copyWith(
      availability: SearchMovieAvailability.single,
    );

    expect(original.type, SearchMovieType.all);
    expect(original.availability, SearchMovieAvailability.all);
    expect(original.sort, SearchMovieSort.relevance);
    expect(changed.availability, SearchMovieAvailability.single);
    expect(changed.type, original.type);
    expect(changed.sort, original.sort);
  });
}
