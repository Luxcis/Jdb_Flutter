import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/cached_image.dart';

void main() {
  testWidgets('ActorCard 渲染头像和名称', (tester) async {
    final actor = ActorSummary(
      id: 'a1',
      name: '测试演员',
      avatarUrl: 'avatars/test.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 120, child: ActorCard(actor: actor)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('测试演员'), findsOneWidget);
  });

  testWidgets('ActorCard onTap 回调触发', (tester) async {
    var tapped = false;
    final actor = ActorSummary(
      id: 'a1',
      name: '测试演员',
      avatarUrl: 'avatars/test.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: ActorCard(actor: actor, onTap: () => tapped = true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('测试演员'));
    expect(tapped, isTrue);
  });

  testWidgets('ActorCard 根据演员性别传递头像占位图', (tester) async {
    final actor = ActorSummary(
      id: 'a1',
      name: '测试男演员',
      avatarUrl: 'avatars/missing.jpg',
      gender: 'male',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 120, child: ActorCard(actor: actor)),
        ),
      ),
    );

    final image = tester.widget<CachedImage>(find.byType(CachedImage));
    expect(image.fallbackAsset, 'assets/images/actor_unknow_male_200x200.jpg');
  });

  testWidgets('ActorCard 使用父级宽度渲染方形头像且名称单行省略', (tester) async {
    const actor = ActorSummary(
      id: 'a1',
      name: '很长很长很长很长的演员名称',
      avatarUrl: 'actors/test.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 120, child: ActorCard(actor: actor)),
        ),
      ),
    );

    expect(find.byType(AspectRatio), findsOneWidget);
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 1);
    final name = tester.widget<Text>(find.text(actor.name));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
  });
}
