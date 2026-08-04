import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';

void main() {
  testWidgets('显示加粗名称影片数查看数箭头并触发点击', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListSummaryTile(
            list: const ListModel(
              id: 'l1',
              name: '收藏精选',
              movieCount: 12,
              viewedCount: 34,
            ),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('收藏精选'), findsOneWidget);
    expect(find.text('12 部影片，被查看 34 次'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('收藏精选')).style?.fontWeight,
      FontWeight.w600,
    );
    await tester.tap(find.byType(ListSummaryTile));
    expect(tapped, isTrue);
  });

  testWidgets('未提供点击回调时保持不可点击', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListSummaryTile(
            list: ListModel(id: 'l1', name: '静态清单'),
          ),
        ),
      ),
    );

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.onTap, isNull);
  });
}
