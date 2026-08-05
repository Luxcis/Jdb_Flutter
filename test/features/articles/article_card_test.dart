import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/articles/models/article.dart';
import 'package:jade/features/articles/widgets/article_card.dart';

void main() {
  ArticleSummary article({
    String id = '1',
    String title = '标题',
    String? author = '作者',
    String? category = '业界',
    String? releasedAt,
    String? coverUrl = 'cover.jpg',
  }) => ArticleSummary(
    id: id,
    title: title,
    author: author,
    category: category,
    releasedAt: releasedAt,
    coverUrl: coverUrl,
  );

  Future<void> pumpCard(WidgetTester tester, ArticleSummary item) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ArticleCard(article: item))),
    );
  }

  testWidgets('渲染标题作者与相对发布时间', (tester) async {
    final releasedAt = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: 3))
        .toIso8601String();
    await pumpCard(tester, article(releasedAt: releasedAt));

    expect(find.text('标题'), findsOneWidget);
    expect(find.text('作者'), findsOneWidget);
    expect(find.textContaining('小时前'), findsOneWidget);
  });

  testWidgets('渲染分类胶囊标签', (tester) async {
    await pumpCard(tester, article(category: '业界'));

    expect(find.text('业界'), findsOneWidget);
    final container = tester.widget<Container>(
      find.ancestor(of: find.text('业界'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, Colors.red);
  });

  testWidgets('category 为空时不渲染标签', (tester) async {
    await pumpCard(tester, article(category: null));

    expect(find.textContaining('业界'), findsNothing);
  });

  testWidgets('封面 16:9 比例', (tester) async {
    await pumpCard(tester, article());

    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspect.aspectRatio, 16 / 9);
  });

  testWidgets('无封面时显示占位而非崩溃', (tester) async {
    await pumpCard(tester, article(coverUrl: null));

    expect(find.byType(AspectRatio), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });
}
