import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_avatar_image.dart';
import 'package:jade/core/widgets/cached_image.dart';

void main() {
  Future<String?> fallbackFor(WidgetTester tester, String? gender) async {
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
      await fallbackFor(tester, 'male'),
      'assets/images/actor_unknow_male_200x200.jpg',
    );
  });

  testWidgets('MALE 性别忽略大小写使用男性占位图', (tester) async {
    expect(
      await fallbackFor(tester, 'MALE'),
      'assets/images/actor_unknow_male_200x200.jpg',
    );
  });

  testWidgets('female 性别使用通用演员占位图', (tester) async {
    expect(
      await fallbackFor(tester, 'female'),
      'assets/images/actor_unknow_200x200.jpg',
    );
  });

  testWidgets('未知性别使用通用演员占位图', (tester) async {
    expect(
      await fallbackFor(tester, null),
      'assets/images/actor_unknow_200x200.jpg',
    );
  });
}
