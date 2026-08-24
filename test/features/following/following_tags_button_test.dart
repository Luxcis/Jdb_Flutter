import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/following/widgets/following_tags_button.dart';

void main() {
  testWidgets('未关注显示 visibility 图标', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FollowingTagsButton(
        following: false,
        enabled: true,
        onPressed: () {},
      )),
    ));
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsNothing);
  });

  testWidgets('已关注显示 visibility_off 图标', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FollowingTagsButton(
        following: true,
        enabled: true,
        onPressed: () {},
      )),
    ));
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });

  testWidgets('enabled=false 时禁用按钮', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FollowingTagsButton(
        following: false,
        enabled: false,
        onPressed: () => pressed = true,
      )),
    ));
    await tester.tap(find.byType(IconButton));
    expect(pressed, isFalse);
  });
}
