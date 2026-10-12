import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:volume_controller/volume_controller.dart';

/// 预告片播放页的系统媒体音量控制器。
///
/// 调节直接作用于系统媒体音量，退出页面后不回退。
abstract interface class MoviePreviewVolumeController {
  /// 当前系统媒体音量（0.0–1.0）。
  Future<double> get current;

  /// 设置系统媒体音量，[value] clamp 在 0.0–1.0。
  Future<void> setVolume(double value);
}

/// 基于 volume_controller 插件的实现。
class SystemMoviePreviewVolumeController
    implements MoviePreviewVolumeController {
  SystemMoviePreviewVolumeController({VolumeController? plugin})
    : _plugin = plugin ?? VolumeController.instance;

  final VolumeController _plugin;

  @override
  Future<double> get current => _plugin.getVolume();

  @override
  Future<void> setVolume(double value) {
    return _plugin.setVolume(value.clamp(0.0, 1.0));
  }
}

/// 测试用内存实现：记录调节过程，可注入初始值与失败。
@visibleForTesting
class FakeMoviePreviewVolumeController implements MoviePreviewVolumeController {
  FakeMoviePreviewVolumeController({double initial = 0.5}) : _value = initial;

  double _value;
  final setValues = <double>[];
  Object? error;

  @override
  Future<double> get current async => _value;

  @override
  Future<void> setVolume(double value) async {
    final failure = error;
    if (failure != null) throw failure;
    _value = value.clamp(0.0, 1.0);
    setValues.add(_value);
  }
}
