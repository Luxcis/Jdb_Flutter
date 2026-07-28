import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/section_header.dart';

void main() {
  testWidgets('全局分区标题使用强调层级并在尾部显示右箭头', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader(title: '最新上架', trailing: '全部'),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('最新上架'));
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('尾部区域整体触发 onTrailing', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionHeader(
            title: '月排名',
            trailing: '全部',
            onTrailing: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('全部'));
    expect(taps, 1);
  });
}
