import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// 预告片播放页的屏幕亮度控制器。
///
/// 调节只作用于应用内亮度，[reset] 恢复跟随系统亮度。
abstract interface class MoviePreviewBrightnessController {
  /// 当前应用亮度（0.0–1.0）。
  Future<double> get current;

  /// 设置应用亮度，[value] clamp 在 0.0–1.0。
  Future<void> setBrightness(double value);

  /// 恢复跟随系统亮度。
  Future<void> reset();
}

/// 基于 screen_brightness 插件的实现。
class SystemMoviePreviewBrightnessController
    implements MoviePreviewBrightnessController {
  SystemMoviePreviewBrightnessController({ScreenBrightness? plugin})
    : _plugin = plugin ?? ScreenBrightness.instance;

  final ScreenBrightness _plugin;

  @override
  Future<double> get current => _plugin.application;

  @override
  Future<void> setBrightness(double value) {
    return _plugin.setApplicationScreenBrightness(value.clamp(0.0, 1.0));
  }

  @override
  Future<void> reset() => _plugin.resetApplicationScreenBrightness();
}

/// 测试用内存实现：记录调节过程，可注入初始值与失败。
@visibleForTesting
class FakeMoviePreviewBrightnessController
    implements MoviePreviewBrightnessController {
  FakeMoviePreviewBrightnessController({double initial = 0.5})
    : _value = initial;

  double _value;
  final setValues = <double>[];
  var resetCalls = 0;
  Object? error;

  @override
  Future<double> get current async => _value;

  @override
  Future<void> setBrightness(double value) async {
    final failure = error;
    if (failure != null) throw failure;
    _value = value.clamp(0.0, 1.0);
    setValues.add(_value);
  }

  @override
  Future<void> reset() async {
    resetCalls++;
  }
}
