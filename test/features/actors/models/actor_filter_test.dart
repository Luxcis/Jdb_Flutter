import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/actors/models/actor_filter.dart';

void main() {
  test('五个分类映射为接口 type 和 gender', () {
    expect(
      ActorListCategory.values
          .map((category) => (category.type, category.gender))
          .toList(),
      [('0', '0'), ('0', '1'), ('1', 'all'), ('2', '0'), ('2', '1')],
    );
  });

  test('只有有码女支持范围筛选', () {
    expect(ActorListCategory.censoredFemale.supportsFilter, isTrue);
    expect(
      ActorListCategory.values
          .where((category) => category != ActorListCategory.censoredFemale)
          .every((category) => !category.supportsFilter),
      isTrue,
    );
  });

  test('默认范围不编码为请求参数', () {
    expect(const ActorFilter().toQueryParameters(), isEmpty);
  });

  test('只编码偏离默认值的范围', () {
    final filter = const ActorFilter().copyWith(
      age: const ActorRange(20, 40),
      cup: const ActorRange(3, 8),
      hips: const ActorRange(80, 100),
    );

    expect(filter.toQueryParameters(), {
      'age': '20,40',
      'cup': '3,8',
      'hips': '80,100',
    });
  });
}
