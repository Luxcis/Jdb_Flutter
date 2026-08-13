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

  /// 全局沉浸式系统覆盖样式(状态栏透明、关闭对比遮罩)
  ///
  /// 供 [AppBarTheme.systemOverlayStyle] 与应用根级 `AnnotatedRegion` 共用,
  /// 确保没有 AppBar 的页面(启动页、首页)也保持一致。
  static SystemUiOverlayStyle systemUiOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
    );
  }

  static AppBarTheme _appBarTheme(Brightness brightness) {
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: systemUiOverlayStyle(brightness),
    );
  }
}
