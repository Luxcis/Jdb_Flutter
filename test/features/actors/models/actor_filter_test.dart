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

  test('有码女/无码/欧美女支持月榜，男类不支持', () {
    expect(ActorListCategory.censoredFemale.supportsRanking, isTrue);
    expect(ActorListCategory.uncensored.supportsRanking, isTrue);
    expect(ActorListCategory.westernFemale.supportsRanking, isTrue);
    expect(ActorListCategory.censoredMale.supportsRanking, isFalse);
    expect(ActorListCategory.westernMale.supportsRanking, isFalse);
  });

  test('默认范围不编码为请求参数', () {
    expect(const ActorFilter().toQueryParameters(), isEmpty);
  });

  test('六个范围相同时筛选条件值相等', () {
    final filter = ActorFilter(
      age: const ActorRange(20, 40),
      height: const ActorRange(150, 170),
      cup: const ActorRange(2, 8),
      bust: const ActorRange(80, 100),
      waist: const ActorRange(55, 75),
      hips: const ActorRange(85, 105),
    );
    final equalFilter = ActorFilter(
      age: const ActorRange(20, 40),
      height: const ActorRange(150, 170),
      cup: const ActorRange(2, 8),
      bust: const ActorRange(80, 100),
      waist: const ActorRange(55, 75),
      hips: const ActorRange(85, 105),
    );

    expect(filter, equalFilter);
    expect(filter.hashCode, equals(equalFilter.hashCode));
  });

  test('任一范围不同则筛选条件不相等', () {
    const filter = ActorFilter();

    expect(filter, isNot(filter.copyWith(age: const ActorRange(20, 65))));
    expect(filter, isNot(filter.copyWith(height: const ActorRange(131, 185))));
    expect(filter, isNot(filter.copyWith(cup: const ActorRange(1, 15))));
    expect(filter, isNot(filter.copyWith(bust: const ActorRange(71, 120))));
    expect(filter, isNot(filter.copyWith(waist: const ActorRange(51, 90))));
    expect(filter, isNot(filter.copyWith(hips: const ActorRange(71, 120))));
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
