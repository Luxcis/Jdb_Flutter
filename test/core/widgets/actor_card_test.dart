import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/cached_image.dart';

/// WCAG 相对亮度对比度。
double _contrastRatio(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

const _actor = ActorSummary(
  id: 'a1',
  name: '测试演员',
  avatarUrl: 'avatars/test.jpg',
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required bool selected,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SizedBox(
          width: 120,
          child: ActorCard(actor: _actor, selected: selected, onTap: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('ActorCard 渲染头像和名称', (tester) async {
    final actor = ActorSummary(
      id: 'a1',
      name: '测试演员',
      avatarUrl: 'avatars/test.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 120, child: ActorCard(actor: actor)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('测试演员'), findsOneWidget);
  });

  testWidgets('ActorCard onTap 回调触发', (tester) async {
    var tapped = false;
    final actor = ActorSummary(
      id: 'a1',
      name: '测试演员',
      avatarUrl: 'avatars/test.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: ActorCard(actor: actor, onTap: () => tapped = true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('测试演员'));
    expect(tapped, isTrue);
  });

  testWidgets('ActorCard 根据演员性别传递头像占位图', (tester) async {
    final actor = ActorSummary(
      id: 'a1',
      name: '测试男演员',
      avatarUrl: 'avatars/missing.jpg',
      gender: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 120, child: ActorCard(actor: actor)),
        ),
      ),
    );

    final image = tester.widget<CachedImage>(find.byType(CachedImage));
    expect(image.fallbackAsset, 'assets/images/actor_unknow_male_200x200.jpg');
  });

  testWidgets('ActorCard 使用父级宽度渲染方形头像且名称单行省略', (tester) async {
    const actor = ActorSummary(
      id: 'a1',
      name: '很长很长很长很长的演员名称',
      avatarUrl: 'actors/test.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 120, child: ActorCard(actor: actor)),
        ),
      ),
    );

    expect(find.byType(AspectRatio), findsOneWidget);
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 1);
    final name = tester.widget<Text>(find.text(actor.name));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
  });

  testWidgets('选中徽章前景使用 colorScheme.onPrimary 且对比度不低于 3:1', (tester) async {
    for (final theme in [
      ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
    ]) {
      // 每轮重建整棵树，确保主题变化不依赖 element 复用。
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpCard(tester, selected: true, theme: theme);

      final colors = theme.colorScheme;
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.color, colors.onPrimary);
      expect(
        _contrastRatio(colors.onPrimary, colors.primary),
        greaterThanOrEqualTo(3.0),
        reason: '明暗主题下勾选图形与徽章底色需满足非文本 3:1',
      );
    }
  });

  testWidgets('未选中时不渲染选中徽章', (tester) async {
    await _pumpCard(tester, selected: false);

    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('Semantics 暴露选中状态', (tester) async {
    final handle = tester.ensureSemantics();

    await _pumpCard(tester, selected: true);
    final selectedNode = tester.getSemantics(find.byType(ActorCard));
    expect(selectedNode.flagsCollection.isSelected, Tristate.isTrue);

    await _pumpCard(tester, selected: false);
    final unselectedNode = tester.getSemantics(find.byType(ActorCard));
    expect(unselectedNode.flagsCollection.isSelected, Tristate.isFalse);

    handle.dispose();
  });
}
