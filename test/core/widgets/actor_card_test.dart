import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_card.dart';

void main() {
  testWidgets('ActorCard 渲染头像和名称', (tester) async {
    final actor = ActorSummary(
      id: 'a1',
      name: '测试演员',
      avatarUrl: 'avatars/test.jpg',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ActorCard(actor: actor)),
    ));
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
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActorCard(actor: actor, onTap: () => tapped = true),
      ),
    ));
    await tester.tap(find.text('测试演员'));
    expect(tapped, isTrue);
  });
}
