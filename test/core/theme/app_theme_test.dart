import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('亮色主题使用透明沉浸式状态栏和深色状态栏图标', () {
      final theme = AppTheme.light();
      final overlayStyle = theme.appBarTheme.systemOverlayStyle;

      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(overlayStyle?.statusBarColor, Colors.transparent);
      expect(overlayStyle?.statusBarIconBrightness, Brightness.dark);
      expect(overlayStyle?.statusBarBrightness, Brightness.light);
      expect(overlayStyle?.systemStatusBarContrastEnforced, isFalse);
    });

    test('深色主题使用透明沉浸式状态栏和浅色状态栏图标', () {
      final theme = AppTheme.dark();
      final overlayStyle = theme.appBarTheme.systemOverlayStyle;

      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(overlayStyle?.statusBarColor, Colors.transparent);
      expect(overlayStyle?.statusBarIconBrightness, Brightness.light);
      expect(overlayStyle?.statusBarBrightness, Brightness.dark);
      expect(overlayStyle?.systemStatusBarContrastEnforced, isFalse);
    });

    test('动态取色主题也保留沉浸式状态栏样式', () {
      final dynamicScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );
      final theme = AppTheme.fromColorScheme(dynamicScheme);

      expect(theme.colorScheme, dynamicScheme);
      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
      expect(
        theme.appBarTheme.systemOverlayStyle?.statusBarColor,
        Colors.transparent,
      );
    });
  });
}
