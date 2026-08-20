import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/favorite_button.dart';

void main() {
  testWidgets('未收藏显示空心爱心，点击回调', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FavoriteButton(
            hasCollected: false,
            onPressed: () => pressed++,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    await tester.tap(find.byType(FavoriteButton));
    expect(pressed, 1);
  });

  testWidgets('已收藏显示实心爱心', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FavoriteButton(
            hasCollected: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('busy 时禁用点击', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FavoriteButton(
            hasCollected: false,
            busy: true,
            onPressed: () => pressed++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FavoriteButton), warnIfMissed: false);
    expect(pressed, 0);
  });
}
