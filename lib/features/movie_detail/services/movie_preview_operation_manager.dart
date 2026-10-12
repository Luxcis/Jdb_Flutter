import 'dart:async';

import 'movie_preview_orientation.dart';
import 'movie_preview_system_ui.dart';
import 'movie_preview_wakelock.dart';

/// 预告片播放页的设备全局操作管理器。
///
/// 将方向锁定、屏幕常亮、系统栏沉浸三种设备状态统一为一个生命周期契约：
/// 页面打开时 [acquire] 获取方向与系统栏；播放开始后通过 [acquireWakelock]
/// 获取屏幕常亮；页面关闭时 [release] 一次性释放全部资源。
class MoviePreviewOperationManager {
  MoviePreviewOperationManager({
    required MoviePreviewOrientationCoordinator orientationCoordinator,
    required MoviePreviewWakelockCoordinator wakelockCoordinator,
    required MoviePreviewSystemUiCoordinator systemUiCoordinator,
  }) : _orientationCoordinator = orientationCoordinator,
       _wakelockCoordinator = wakelockCoordinator,
       _systemUiCoordinator = systemUiCoordinator;

  static final system = MoviePreviewOperationManager(
    orientationCoordinator: MoviePreviewOrientationCoordinator.system,
    wakelockCoordinator: MoviePreviewWakelockCoordinator.system,
    systemUiCoordinator: MoviePreviewSystemUiCoordinator.system,
  );

  final MoviePreviewOrientationCoordinator _orientationCoordinator;
  final MoviePreviewWakelockCoordinator _wakelockCoordinator;
  final MoviePreviewSystemUiCoordinator _systemUiCoordinator;

  MoviePreviewOperationLease? _activeLease;

  /// 获取方向与系统栏的所有权，返回一个统一 lease。
  ///
  /// 调用方应等待 [MoviePreviewOperationLease.orientationLocked] 完成后再开始
  /// 初始化播放资源；系统栏的进入操作由本管理器内部调度，失败不会抛出。
  MoviePreviewOperationLease acquire() {
    final lease = MoviePreviewOperationLease._(
      orientationLease: _orientationCoordinator.acquire(),
      systemUiLease: _systemUiCoordinator.acquire(),
    );
    _activeLease = lease;
    return lease;
  }

  /// 在播放成功开始后获取屏幕常亮。
  void acquireWakelock(MoviePreviewOperationLease lease) {
    if (lease._wakelockLease != null) return;
    lease._wakelockLease = _wakelockCoordinator.acquire();
  }

  /// 当方向锁定失败需要重试时，释放旧的方向 lease 并创建新的方向 lease，
  /// 同时保留原有的系统栏与 wakelock lease。
  MoviePreviewOperationLease replaceOrientationLease(
    MoviePreviewOperationLease lease,
  ) {
    unawaited(_ignoreErrors(lease.orientationLease.release()));
    final newLease = MoviePreviewOperationLease._(
      orientationLease: _orientationCoordinator.acquire(),
      systemUiLease: lease.systemUiLease,
      wakelockLease: lease._wakelockLease,
    );
    if (identical(_activeLease, lease)) {
      _activeLease = newLease;
    }
    return newLease;
  }

  /// 释放当前持有的全部设备状态。
  ///
  /// 各子操作的失败被忽略，确保清理路径尽可能完成。
  Future<void> release() async {
    final lease = _activeLease;
    _activeLease = null;
    if (lease == null) return;

    await Future.wait([
      _ignoreErrors(lease.orientationLease.release()),
      _ignoreErrors(lease._wakelockLease?.release() ?? Future<void>.value()),
      _ignoreErrors(lease.systemUiLease.release()),
    ]);
  }

  Future<void> _ignoreErrors(Future<void> future) async {
    try {
      await future;
    } on Object {
      // 清理路径故意忽略失败。
    }
  }
}

/// [MoviePreviewOperationManager.acquire] 返回的统一 lease。
class MoviePreviewOperationLease {
  MoviePreviewOperationLease._({
    required this.orientationLease,
    required this.systemUiLease,
    MoviePreviewWakelockLease? wakelockLease,
  }) : _wakelockLease = wakelockLease;

  final MoviePreviewOrientationLease orientationLease;
  final MoviePreviewSystemUiLease systemUiLease;
  MoviePreviewWakelockLease? _wakelockLease;

  /// 方向锁定完成的 future；成功后才应开始初始化播放。
  Future<void> get orientationLocked => orientationLease.locked;
}
