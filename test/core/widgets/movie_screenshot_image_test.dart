import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/movie_screenshot_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsProvider> _createSettings({bool blur = true}) async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.blurMovieImages: blur,
  });
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
  testWidgets('影片剧照响应全局模糊开关', (tester) async {
    final settings = await _createSettings(blur: false);
    await _pumpWithSettings(
      tester,
      settings,
      const MovieScreenshotImage('screenshots/test.jpg'),
    );

    expect(tester.widget<CachedImage>(find.byType(CachedImage)).blur, isFalse);

    await settings.setBlurMovieImages(true);
    await tester.pump();
    expect(tester.widget<CachedImage>(find.byType(CachedImage)).blur, isTrue);
  });
}
