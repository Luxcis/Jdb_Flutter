import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_list_tile.dart';
import 'package:jade/core/widgets/movie_screenshot_image.dart';

void main() {
  testWidgets('MovieCard 渲染封面标题番号', (tester) async {
    final movie = MovieSummary(
      id: '1',
      number: 'SSIS-001',
      title: 'Test Movie',
      coverUrl: 'covers/x.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieCard(movie: movie)),
      ),
    );
    expect(find.text('Test Movie'), findsOneWidget);
    expect(find.text('SSIS-001'), findsOneWidget);
  });

  testWidgets('MovieCard 封面按比例完整缩放', (tester) async {
    final movie = MovieSummary(
      id: '1',
      number: 'SSIS-001',
      title: 'Test Movie',
      coverUrl: 'covers/x.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieCard(movie: movie)),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('MovieCard 封面优先使用 thumb_url', (tester) async {
    final movie = MovieSummary.fromJson({
      'id': '1',
      'number': 'SSIS-001',
      'title': 'Test Movie',
      'cover_url': 'covers/cover.jpg',
      'thumb_url': 'thumbs/thumb.jpg',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieCard(movie: movie)),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, endsWith('thumbs/thumb.jpg'));
  });

  testWidgets('MovieCard 缺少 thumbUrl 时仍使用缩略图占位', (tester) async {
    final movie = MovieSummary(
      id: '1',
      number: 'SSIS-001',
      title: 'Test Movie',
      coverUrl: 'covers/cover.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MovieCard(movie: movie)),
      ),
    );

    final image = tester.widget<CachedImage>(find.byType(CachedImage));
    expect(image.fallbackAsset, 'assets/images/noimage_147x200.jpg');
  });

  testWidgets('MovieCard onTap 回调', (tester) async {
    var tapped = false;
    final movie = MovieSummary(
      id: '1',
      number: 'ABC-001',
      title: 'Tap Me',
      coverUrl: 'x.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MovieCard(movie: movie, onTap: () => tapped = true),
        ),
      ),
    );
    await tester.tap(find.text('Tap Me'));
    expect(tapped, isTrue);
  });

  group('MovieListTile', () {
    testWidgets('基础渲染标题、番号、日期', (tester) async {
      final movie = MovieSummary(
        id: '1',
        number: 'SSIS-001',
        title: '测试影片标题',
        coverUrl: 'covers/test.jpg',
        releaseDate: '2024-01-01',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MovieListTile(movie: movie, rank: 1)),
        ),
      );
      await tester.pump();
      expect(find.text('测试影片标题'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data!.contains('SSIS-001'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data!.contains('2024-01-01'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('screenshots 参数渲染横向截图', (tester) async {
      final movie = MovieSummary(
        id: '1',
        number: 'SSIS-001',
        title: '测试影片',
        coverUrl: 'covers/test.jpg',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MovieListTile(
              movie: movie,
              screenshots: ['shot1.jpg', 'shot2.jpg'],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CachedImage), findsNWidgets(3));
      expect(find.byType(MovieScreenshotImage), findsNWidgets(2));
    });

    testWidgets('无 screenshots 时不渲染截图区域', (tester) async {
      final movie = MovieSummary(
        id: '1',
        number: 'SSIS-001',
        title: '测试影片',
        coverUrl: 'covers/test.jpg',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MovieListTile(movie: movie)),
        ),
      );
      await tester.pump();
      expect(find.byType(CachedImage), findsOneWidget);
    });
  });
}
