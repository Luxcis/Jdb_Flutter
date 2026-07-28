import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/sort_segmented.dart';

void main() {
  testWidgets('默认模式保持原有尺寸和选中图标', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SortSegmented<String>(
            options: const [
              (label: '日榜', value: 'daily'),
              (label: '周榜', value: 'weekly'),
            ],
            value: 'daily',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final segmented = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(segmented.showSelectedIcon, isTrue);
    expect(segmented.expandedInsets, isNull);
    expect(segmented.style, isNull);
  });

  testWidgets('紧凑撑满模式应用收缩样式并填满父级', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SortSegmented<String>(
                compact: true,
                expanded: true,
                options: const [
                  (label: '日榜', value: 'daily'),
                  (label: '周榜', value: 'weekly'),
                  (label: '月榜', value: 'monthly'),
                ],
                value: 'daily',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final finder = find.byType(SegmentedButton<String>);
    final segmented = tester.widget<SegmentedButton<String>>(finder);
    expect(segmented.showSelectedIcon, isFalse);
    expect(segmented.expandedInsets, EdgeInsets.zero);
    expect(segmented.style?.visualDensity, VisualDensity.compact);
    expect(segmented.style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    expect(
      segmented.style?.padding?.resolve(<WidgetState>{}),
      const EdgeInsets.symmetric(horizontal: 8),
    );
    expect(tester.getSize(finder).width, 300);
  });
}
