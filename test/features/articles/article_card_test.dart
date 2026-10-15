import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/articles/models/article.dart';
import 'package:jade/features/articles/widgets/article_card.dart';
import 'package:jade/features/articles/widgets/article_cover_image.dart';

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
      MaterialApp(
        home: Scaffold(body: ArticleCard(article: item)),
      ),
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
      find
          .ancestor(of: find.text('业界'), matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    final context = tester.element(find.text('业界'));
    expect(decoration.color, Theme.of(context).colorScheme.error);
  });

  testWidgets('category 为空时不渲染标签', (tester) async {
    await pumpCard(tester, article(category: null));

    expect(find.textContaining('业界'), findsNothing);
  });

  testWidgets('无封面时显示 16:9 占位兜底图', (tester) async {
    await pumpCard(tester, article(coverUrl: null));

    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspect.aspectRatio, 16 / 9);
    expect(find.byType(ArticleCoverImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('加载前封面使用 16:9 占位区', (tester) async {
    await pumpCard(tester, article(coverUrl: 'cover.jpg'));

    final coverImage = tester.widget<ArticleCoverImage>(
      find.byType(ArticleCoverImage),
    );
    expect(coverImage.url, 'cover.jpg');
    expect(coverImage.semanticLabel, '标题');

    // 图片尺寸未解锁前保持 16:9 占位高度（视口宽 800）。
    const cardWidth = 800.0;
    final placeholderHeight = cardWidth * 9 / 16;
    final placeholders = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(ArticleCoverImage),
            matching: find.byType(SizedBox),
          ),
        )
        .where(
          (box) =>
              box.width == cardWidth &&
              box.height != null &&
              (box.height! - placeholderHeight).abs() < 1,
        )
        .toList();
    expect(placeholders, isNotEmpty);
  });

  group('resolveDisplayHeight', () {
    test('宽幅封面按真实比例完整自适应', () {
      const width = 800.0;
      final height = ArticleCoverImage.resolveDisplayHeight(
        coverWidth: width,
        imageSize: const Size(1920, 800),
      );
      expect(height, closeTo(width * 800 / 1920, 0.01));
      expect(height, lessThan(width * ArticleCoverImage.maxHeightFactor));
    });

    test('竖版封面未超限时完整显示', () {
      const width = 400.0;
      final height = ArticleCoverImage.resolveDisplayHeight(
        coverWidth: width,
        imageSize: const Size(900, 800),
      );
      expect(height, closeTo(width * 800 / 900, 0.01));
      expect(height, lessThanOrEqualTo(width * ArticleCoverImage.maxHeightFactor));
    });

    test('超高封面被截断为宽度上限并触发顶部裁剪', () {
      const width = 400.0;
      final height = ArticleCoverImage.resolveDisplayHeight(
        coverWidth: width,
        imageSize: const Size(500, 1000),
      );
      expect(height, width * ArticleCoverImage.maxHeightFactor);
    });
  });
}
