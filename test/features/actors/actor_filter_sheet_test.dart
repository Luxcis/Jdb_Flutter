import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/actors/models/actor_filter.dart';
import 'package:jade/features/actors/widgets/actor_filter_sheet.dart';

void main() {
  testWidgets('六个范围滑块语义播报实际端点和单位', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActorFilterSheet(
            initialValue: ActorFilter(
              age: ActorRange(20, 40),
              height: ActorRange(131, 184),
              cup: ActorRange(1, 14),
              bust: ActorRange(71, 119),
              waist: ActorRange(51, 89),
              hips: ActorRange(72, 118),
            ),
          ),
        ),
      ),
    );

    final semanticValues = <String>{};
    void collectValues(SemanticsNode node) {
      final value = node.getSemanticsData().value;
      if (value.isNotEmpty) semanticValues.add(value);
      node.visitChildren((child) {
        collectValues(child);
        return true;
      });
    }

    for (var index = 0; index < 6; index++) {
      collectValues(tester.getSemantics(find.byType(RangeSlider).at(index)));
    }

    for (final value in [
      '20岁',
      '40岁',
      '131厘米',
      '184厘米',
      'B罩杯',
      'O罩杯',
      '71厘米',
      '119厘米',
      '51厘米',
      '89厘米',
      '72厘米',
      '118厘米',
    ]) {
      expect(semanticValues, contains(value));
    }

    semanticsHandle.dispose();
  });

  testWidgets('筛选面板紧凑展示六个范围并可重置', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActorFilterSheet(
            initialValue: ActorFilter(age: ActorRange(20, 40)),
          ),
        ),
      ),
    );

    for (final label in ['年龄', '身高', '罩杯', '胸围', '腰围', '臀围']) {
      expect(find.text(label), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('$label筛选')), findsOneWidget);
    }
    expect(find.text('20–40'), findsOneWidget);

    await tester.tap(find.text('重置'));
    await tester.pump();

    expect(find.text('19–65'), findsOneWidget);
    expect(find.text('A–P'), findsOneWidget);

    semanticsHandle.dispose();
  });

  testWidgets('应用返回草稿筛选，系统返回不应用', (tester) async {
    const initialValue = ActorFilter(age: ActorRange(20, 40));
    final results = <ActorFilter?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('open-filter-sheet'),
            onPressed: () async {
              results.add(
                await showModalBottomSheet<ActorFilter>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) =>
                      const ActorFilterSheet(initialValue: initialValue),
                ),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-filter-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置'));
    await tester.pump();
    await tester.ensureVisible(find.text('应用筛选'));
    await tester.tap(find.text('应用筛选'));
    await tester.pumpAndSettle();

    expect(results, [const ActorFilter()]);
    expect(initialValue, const ActorFilter(age: ActorRange(20, 40)));

    await tester.tap(find.byKey(const Key('open-filter-sheet')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(results, [const ActorFilter(), isNull]);
  });
}
