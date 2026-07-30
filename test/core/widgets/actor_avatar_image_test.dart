import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_avatar_image.dart';
import 'package:jade/core/widgets/cached_image.dart';

void main() {
  Future<String?> fallbackFor(WidgetTester tester, int? gender) async {
    final actor = ActorSummary(
      id: 'a1',
      name: '测试演员',
      avatarUrl: 'actors/missing.jpg',
      gender: gender,
    );
    await tester.pumpWidget(MaterialApp(home: ActorAvatarImage(actor)));
    return tester.widget<CachedImage>(find.byType(CachedImage)).fallbackAsset;
  }

  testWidgets('male 性别使用男性占位图', (tester) async {
    expect(
      await fallbackFor(tester, 1),
      'assets/images/actor_unknow_male_200x200.jpg',
    );
  });

  testWidgets('female 性别使用通用演员占位图', (tester) async {
    expect(
      await fallbackFor(tester, 0),
      'assets/images/actor_unknow_200x200.jpg',
    );
  });

  testWidgets('未知性别使用通用演员占位图', (tester) async {
    expect(
      await fallbackFor(tester, null),
      'assets/images/actor_unknow_200x200.jpg',
    );
  });

  testWidgets('演员头像由组件自身使用 8px 圆角裁切', (tester) async {
    const actor = ActorSummary(
      id: 'a1',
      name: '测试演员',
      avatarUrl: 'actors/test.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.square(dimension: 80, child: ActorAvatarImage(actor)),
      ),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(8));
  });
}
