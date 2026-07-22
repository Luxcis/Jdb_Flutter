import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/tag_chip.dart';

void main() {
  testWidgets('TagChip 默认不强制紧凑样式', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TagChip(label: '剧情')),
      ),
    );

    final chip = tester.widget<ActionChip>(find.byType(ActionChip));
    expect(chip.visualDensity, isNull);
    expect(chip.materialTapTargetSize, isNull);
    expect(chip.labelStyle, isNull);
    expect(chip.padding, isNull);
    expect(chip.labelPadding, isNull);
  });

  testWidgets('TagChip compact 使用紧凑密度和小号文字', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TagChip(label: '剧情', compact: true)),
      ),
    );

    final context = tester.element(find.byType(ActionChip));
    final chip = tester.widget<ActionChip>(find.byType(ActionChip));
    expect(chip.visualDensity, VisualDensity.compact);
    expect(chip.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
    expect(chip.labelStyle, Theme.of(context).textTheme.labelSmall);
    expect(chip.padding, EdgeInsets.zero);
    expect(chip.labelPadding, const EdgeInsets.symmetric(horizontal: 6));
  });
}
