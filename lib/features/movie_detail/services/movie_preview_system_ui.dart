import 'dart:async';

import 'package:flutter/services.dart';

/// 设置系统栏模式的回调。
///
/// [mode] 为目标系统栏模式；[overlays] 为可选的系统栏叠加项集合。
typedef MoviePreviewSystemUiModeSetter =
    Future<void> Function(SystemUiMode mode, {List<SystemUiOverlay>? overlays});

/// 协调预告片页面沉浸式系统栏的所有权，防止重叠页面之间的迟到恢复竞态。
///
/// 沿用 [MoviePreviewOrientationCoordinator] 的 lease 与串行队列模式，
/// 并强化 release 时序（修复 release 早于 acquire 完成的竞态）。
class MoviePreviewSystemUiCoordinator {
  MoviePreviewSystemUiCoordinator({
    required MoviePreviewSystemUiModeSetter setSystemUiMode,
  }) : _setSystemUiMode = setSystemUiMode;

  static final system = MoviePreviewSystemUiCoordinator(
    setSystemUiMode: SystemChrome.setEnabledSystemUIMode,
  );

  static const enterMode = SystemUiMode.immersiveSticky;
  static const exitMode = SystemUiMode.manual;
  static const exitOverlays = [SystemUiOverlay.top, SystemUiOverlay.bottom];

  final MoviePreviewSystemUiModeSetter _setSystemUiMode;
  Future<void> _pendingOperation = Future<void>.value();
  MoviePreviewSystemUiLease? _owner;

  MoviePreviewSystemUiLease acquire() {
    final lease = MoviePreviewSystemUiLease._(this);
    _owner = lease;
    lease._enabled = _enqueue(() async {
      _ensureOwner(lease);
      await _setSystemUiMode(enterMode);
      _ensureOwner(lease);
    });
    return lease;
  }

  Future<void> _release(MoviePreviewSystemUiLease lease) {
    if (!identical(_owner, lease)) {
      return Future<void>.value();
    }
    return _enqueue(() async {
      if (!identical(_owner, lease)) return;
      _owner = null;
      await _setSystemUiMode(exitMode, overlays: exitOverlays);
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pendingOperation.then((_) => operation());
    _pendingOperation = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void _ensureOwner(MoviePreviewSystemUiLease lease) {
    if (!identical(_owner, lease)) {
      throw StateError('Movie preview system UI lease was superseded');
    }
  }
}

/// 协调器授予的系统栏所有权 lease。
///
/// 持有期间页面处于沉浸模式；调用 [release] 归还所有权并恢复默认系统栏。
/// 若 lease 已被新的 acquire 取代，则其 release 不再生效。
class MoviePreviewSystemUiLease {
  MoviePreviewSystemUiLease._(this._coordinator);

  final MoviePreviewSystemUiCoordinator _coordinator;
  late final Future<void> _enabled;
  Future<void>? _release;

  /// 进入沉浸模式的操作，完成时表示系统栏已隐藏（或失败）。
  Future<void> get enabled => _enabled;

  /// 归还所有权并恢复默认系统栏；重复调用返回同一个 Future。
  Future<void> release() => _release ??= _coordinator._release(this);
}
