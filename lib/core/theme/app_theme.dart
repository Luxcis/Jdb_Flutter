import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 应用配色种子
///
/// Primary:    #63ABA9  主色（青瓷绿）
/// Secondary:  #849493  次要色（灰绿）
/// Tertiary:   #8592A4  第三色（蓝灰）
/// Error:      #FF5449  错误色（暖红）
/// Neutral:    #909190  中性色
/// Neutral Variant: #8C9291  中性变体
abstract final class AppTheme {
  AppTheme._();

  /// 主色种子 — 基于 #63ABA9
  static const Color seedColor = Color(0xFF63ABA9);

  /// 亮色主题（浅色模式）
  static ThemeData light() {
    return fromColorScheme(
      ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
    );
  }

  /// 暗色主题（深色模式）
  static ThemeData dark() {
    return fromColorScheme(
      ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
    );
  }

  static ThemeData fromColorScheme(ColorScheme colorScheme) {
    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: _appBarTheme(colorScheme.brightness),
    );
  }

  static AppBarTheme _appBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemStatusBarContrastEnforced: false,
      ),
    );
  }
}
