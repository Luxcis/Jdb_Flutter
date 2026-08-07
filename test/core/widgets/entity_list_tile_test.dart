import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';

void main() {
  testWidgets('同行显示名称和灰色括号数量并触发点击', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityListTile(
            name: 'ハッピー山田',
            count: 9,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('ハッピー山田'), findsOneWidget);
    expect(find.text('(9)'), findsOneWidget);
    final nameTopLeft = tester.getTopLeft(find.text('ハッピー山田'));
    final countTopLeft = tester.getTopLeft(find.text('(9)'));
    expect(countTopLeft.dy, nameTopLeft.dy);
    expect(countTopLeft.dx, greaterThan(nameTopLeft.dx));
    final count = tester.widget<Text>(find.text('(9)'));
    expect(
      count.style?.color,
      Theme.of(tester.element(find.text('(9)'))).colorScheme.onSurfaceVariant,
    );
    await tester.tap(find.byType(EntityListTile));
    expect(tapped, isTrue);
  });

  testWidgets('相邻行使用相同背景而不是斑马纹', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EntityListTile(
                key: const Key('row-1'),
                name: 'A',
                count: 1,
                onTap: () {},
              ),
              EntityListTile(
                key: const Key('row-2'),
                name: 'B',
                count: 2,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final first = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('row-1')),
            matching: find.byType(Material),
          )
          .first,
    );
    final second = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('row-2')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      first.color,
      Theme.of(
        tester.element(find.byKey(const Key('row-1'))),
      ).colorScheme.surface,
    );
    expect(second.color, first.color);
  });

  testWidgets('可选副标题渲染在名称下方', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityListTile(
            name: 'IPX',
            count: 998,
            subtitle: 'IdeaPocket美少女夢工廠',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('IPX'), findsOneWidget);
    expect(find.text('(998)'), findsOneWidget);
    expect(find.text('IdeaPocket美少女夢工廠'), findsOneWidget);
    final nameTopLeft = tester.getTopLeft(find.text('IPX'));
    final countTopLeft = tester.getTopLeft(find.text('(998)'));
    final subtitleTopLeft = tester.getTopLeft(find.text('IdeaPocket美少女夢工廠'));
    expect(countTopLeft.dy, nameTopLeft.dy);
    expect(countTopLeft.dx, greaterThan(nameTopLeft.dx));
    expect(subtitleTopLeft.dy, greaterThan(countTopLeft.dy));
  });
}
