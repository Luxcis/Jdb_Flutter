import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';

void main() {
  testWidgets('thumbnail 场景使用 147x200 占位图', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MovieCoverImage(
          'covers/thumb.jpg',
          variant: MovieImageVariant.thumbnail,
        ),
      ),
    );

    final image = tester.widget<CachedImage>(find.byType(CachedImage));
    expect(image.fallbackAsset, 'assets/images/noimage_147x200.jpg');
  });

  testWidgets('cover 场景使用 600x404 占位图', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MovieCoverImage(
          'covers/wide.jpg',
          variant: MovieImageVariant.cover,
        ),
      ),
    );

    final image = tester.widget<CachedImage>(find.byType(CachedImage));
    expect(image.fallbackAsset, 'assets/images/noimage_600x404.jpg');
  });
}
