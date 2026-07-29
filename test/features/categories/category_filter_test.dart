import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';

void main() {
  test('五个类型的空筛选保留固定七段', () {
    for (var type = 0; type < 5; type++) {
      expect(const CategoryFilter().toFilterBy(type, const []), '$type:t:::::');
    }
  });

  test('按 category_id 写入固定段位并稳定拼接 extra', () {
    final filter = const CategoryFilter()
        .toggle('main', 'm')
        .toggle('subject', '23')
        .toggle('role', '158')
        .toggle('year', '2024')
        .toggle('duration', '120')
        .toggle('month', '01');

    expect(
      filter.toFilterBy(0, const [
        'main',
        'role',
        'subject',
        'year',
        'duration',
        'month',
      ]),
      '0:t:m:158,23:2024:120:01',
    );
  });

  test('固定段单选可替换和取消，extra 分组可多选', () {
    final filter = const CategoryFilter()
        .toggle('main', 'p')
        .toggle('main', 'm')
        .toggle('subject', '23')
        .toggle('subject', '51')
        .toggle('main', 'm');

    expect(filter.main, isNull);
    expect(filter.selectedValues('subject'), {'23', '51'});
  });

  test('解析接口返回的动态标签分组', () {
    final group = CategoryTagGroup.fromJson({
      'category': '题材',
      'category_id': 'subject',
      'tags': [
        {'id': '23', 'name': '剧情', 'videos_count': 12},
      ],
    });

    expect(group.category, '题材');
    expect(group.categoryId, 'subject');
    expect(group.tags.single.id, '23');
    expect(group.tags.single.videosCount, 12);
  });
}
