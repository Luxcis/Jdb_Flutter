import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/star_rating.dart';

void main() {
  testWidgets('交互评分五颗星分别回调 1 到 5', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StarRating(
            score: selected?.toDouble() ?? 0,
            size: 32,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    for (var value = 1; value <= 5; value++) {
      await tester.tap(find.byKey(Key('star-rating-$value')));
      expect(selected, value);
    }
  });

  testWidgets('交互评分按选中整数显示实心星且没有半星', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StarRating(score: 3, onChanged: (_) {})),
      ),
    );

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.star_half_rounded), findsNothing);
  });

  testWidgets('交互评分禁用时保持选中显示且不回调', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StarRating(score: 4, enabled: false, onChanged: (_) => calls++),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('star-rating-2')));
    expect(calls, 0);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
  });

  testWidgets('交互评分每颗星具有独立按钮语义', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StarRating(score: 0, onChanged: (_) {})),
      ),
    );

    for (var value = 1; value <= 5; value++) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '$value分' &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
    }
    handle.dispose();
  });

  testWidgets('交互评分每颗星点击区域至少 48 像素', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StarRating(score: 0, size: 18, onChanged: (_) {})),
      ),
    );

    for (var value = 1; value <= 5; value++) {
      final size = tester.getSize(find.byKey(Key('star-rating-$value')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
