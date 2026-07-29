import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/models/category_tag.dart';

void main() {
  test('默认筛选可使用 const 构造', () {
    const filter = CategoryFilter();

    expect(filter.toFilterBy(0, const []), '0:t:::::');
  });

  test('五个类型的空筛选保留固定七段', () {
    for (var type = 0; type < 5; type++) {
      expect(CategoryFilter().toFilterBy(type, const []), '$type:t:::::');
    }
  });

  test('非法类型抛出带范围和参数名的 RangeError', () {
    for (final type in [-1, 5]) {
      expect(
        () => CategoryFilter().toFilterBy(type, const []),
        throwsA(
          isA<RangeError>()
              .having((error) => error.invalidValue, 'invalidValue', type)
              .having((error) => error.start, 'start', 0)
              .having((error) => error.end, 'end', 4)
              .having((error) => error.name, 'name', 'type'),
        ),
      );
    }
  });

  test('按 category_id 写入固定段位并稳定拼接 extra', () {
    final filter = CategoryFilter()
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
    final filter = CategoryFilter()
        .toggle('main', 'p')
        .toggle('main', 'm')
        .toggle('subject', '23')
        .toggle('subject', '51')
        .toggle('main', 'm');

    expect(filter.main, isNull);
    expect(filter.selectedValues('subject'), {'23', '51'});
  });

  test('构造和复制后 extra 分组与外部集合隔离且不可变', () {
    final source = <String, Set<String>>{
      'subject': <String>{'23'},
    };
    final filter = const CategoryFilter().copyWith(extraByCategory: source);
    source['subject']!.add('51');
    source['role'] = <String>{'158'};

    expect(filter.selectedValues('subject'), {'23'});
    expect(filter.selectedValues('role'), isEmpty);
    expect(
      () => filter.extraByCategory['subject']!.add('51'),
      throwsUnsupportedError,
    );
    expect(
      () => filter.extraByCategory['role'] = <String>{'158'},
      throwsUnsupportedError,
    );

    final copiedSource = <String, Set<String>>{
      'subject': <String>{'23'},
    };
    final copied = filter.copyWith(extraByCategory: copiedSource);
    copiedSource['subject']!.add('51');

    expect(copied.selectedValues('subject'), {'23'});
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
