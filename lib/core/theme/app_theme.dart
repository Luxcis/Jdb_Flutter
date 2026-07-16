import 'package:flutter/material.dart';

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
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
    );
  }

  /// 暗色主题（深色模式）
  static ThemeData dark() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
    );
  }
}
