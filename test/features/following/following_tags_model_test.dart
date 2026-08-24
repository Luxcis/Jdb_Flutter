import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/following/models/follow_tag.dart';

void main() {
  test('fromJson 解析 id 为字符串且容忍数字 id', () {
    final item = FollowTagItem.fromJson({
      'id': 13384922,
      'name': '有碼,森螢',
      'value': '0:a:g1Q',
      'priority': 6.0,
    });
    expect(item.id, '13384922');
    expect(item.name, '有碼,森螢');
    expect(item.value, '0:a:g1Q');
    expect(item.priority, 6.0);
  });

  test('fromJson 缺省 priority 为 null', () {
    final item = FollowTagItem.fromJson({'id': '1', 'name': 'n', 'value': 'v'});
    expect(item.priority, isNull);
  });

  test('toJson 往返保留字段', () {
    final item = FollowTagItem(
      id: '1',
      name: 'n',
      value: 'v',
      priority: 2,
    );
    expect(item.toJson(), {'id': '1', 'name': 'n', 'value': 'v', 'priority': 2});
  });
}
