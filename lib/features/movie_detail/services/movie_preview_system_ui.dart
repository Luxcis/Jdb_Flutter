import 'dart:async';

import 'package:flutter/services.dart';

typedef MoviePreviewSystemUiModeSetter = Future<void> Function(
  SystemUiMode mode, {
  List<SystemUiOverlay>? overlays,
});

/// 协调预告片页面沉浸式系统栏的所有权，防止重叠页面之间的迟到恢复竞态。
///
/// 与 [MoviePreviewOrientationCoordinator] 同构：acquire 返回 lease，
/// 内部串行队列保证调用顺序；旧 lease 被取代后其释放不再生效。
class MoviePreviewSystemUiCoordinator {
  MoviePreviewSystemUiCoordinator({
    required MoviePreviewSystemUiModeSetter setSystemUiMode,
  }) : _setSystemUiMode = setSystemUiMode;

  static final system = MoviePreviewSystemUiCoordinator(
    setSystemUiMode: SystemChrome.setEnabledSystemUIMode,
  );

  static const enterMode = SystemUiMode.immersiveSticky;
  static const exitMode = SystemUiMode.manual;
  static const exitOverlays = [
    SystemUiOverlay.top,
    SystemUiOverlay.bottom,
  ];

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

class MoviePreviewSystemUiLease {
  MoviePreviewSystemUiLease._(this._coordinator);

  final MoviePreviewSystemUiCoordinator _coordinator;
  late final Future<void> _enabled;
  Future<void>? _release;

  Future<void> get enabled => _enabled;

  Future<void> release() => _release ??= _coordinator._release(this);
}
