import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/rating_badge.dart';

/// WCAG 相对亮度对比度。
double contrastRatio(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

({Color background, Color foreground}) badgeColors(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(RatingBadge),
      matching: find.byType(Container),
    ),
  );
  final decoration = container.decoration! as BoxDecoration;
  final text = tester.widget<Text>(
    find.descendant(of: find.byType(RatingBadge), matching: find.byType(Text)),
  );
  return (background: decoration.color!, foreground: text.style!.color!);
}

Future<void> pumpBadge(WidgetTester tester, int rank) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: RatingBadge(rank: rank)),
      ),
    ),
  );
}

void main() {
  testWidgets('前三名徽章文字对比度不低于 4.5:1', (tester) async {
    for (final rank in const [1, 2, 3]) {
      await pumpBadge(tester, rank);
      final colors = badgeColors(tester);
      expect(
        contrastRatio(colors.foreground, colors.background),
        greaterThanOrEqualTo(4.5),
        reason: '第 $rank 名前景 ${colors.foreground} / 底色 ${colors.background}',
      );
    }
  });

  testWidgets('前三名使用深色前景而非白色', (tester) async {
    for (final rank in const [1, 2, 3]) {
      await pumpBadge(tester, rank);
      final colors = badgeColors(tester);
      expect(colors.foreground, isNot(Colors.white), reason: '第 $rank 名');
      expect(colors.foreground.computeLuminance(), lessThan(0.2));
    }
  });

  testWidgets('读屏朗读“第 N 名”且不重复朗读数字', (tester) async {
    final semantics = tester.ensureSemantics();

    await pumpBadge(tester, 1);

    expect(find.bySemanticsLabel('第 1 名'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^1\$')), findsNothing);

    final node = tester.getSemantics(find.byType(RatingBadge));
    expect(node.label, '第 1 名');

    semantics.dispose();
  });

  testWidgets('十名以后仍朗读完整名次', (tester) async {
    final semantics = tester.ensureSemantics();

    await pumpBadge(tester, 12);

    expect(find.bySemanticsLabel('第 12 名'), findsOneWidget);

    semantics.dispose();
  });
}
