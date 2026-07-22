import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> _createSettings({bool blur = true}) async {
  SharedPreferences.setMockInitialValues({StorageKeys.blurMovieImages: blur});
  final prefs = await SharedPreferences.getInstance();
  return SettingsProvider.create(prefs);
}

Future<void> _pumpWithSettings(
  WidgetTester tester,
  SettingsProvider settings,
  Widget child,
) {
  return tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(home: child),
    ),
  );
}

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

  testWidgets('影片封面响应全局模糊开关', (tester) async {
    final settings = await _createSettings();
    await _pumpWithSettings(
      tester,
      settings,
      const MovieCoverImage(
        'covers/test.jpg',
        variant: MovieImageVariant.thumbnail,
      ),
    );
    expect(tester.widget<CachedImage>(find.byType(CachedImage)).blur, isTrue);

    await settings.setBlurMovieImages(false);
    await tester.pump();
    expect(tester.widget<CachedImage>(find.byType(CachedImage)).blur, isFalse);
  });
}
