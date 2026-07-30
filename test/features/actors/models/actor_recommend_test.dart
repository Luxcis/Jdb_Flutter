import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/actors/models/actor_recommend.dart';

void main() {
  test('ActorRecommend 分别解析三组演员并应用中文名优先级', () {
    final result = ActorRecommend.fromJson({
      'new_actors': [
        {'id': 'n1', 'name': '新人', 'name_zht': '新人中文', 'avatar_url': ''},
      ],
      'monthly_actors': [
        {'id': 'm1', 'name': '月榜', 'avatar_url': ''},
      ],
      'recommend_actors': [
        {'id': 'd1', 'name': 'DMM', 'avatar_url': ''},
      ],
    });

    expect(result.newActors.single.name, '新人中文');
    expect(result.monthlyActors.single.id, 'm1');
    expect(result.recommendActors.single.id, 'd1');
  });
}
