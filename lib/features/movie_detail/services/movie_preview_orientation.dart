import 'dart:async';

import 'package:flutter/services.dart';

typedef MoviePreviewPreferredOrientationsSetter =
    Future<void> Function(List<DeviceOrientation> orientations);

class MoviePreviewOrientationCoordinator {
  MoviePreviewOrientationCoordinator({
    required MoviePreviewPreferredOrientationsSetter setPreferredOrientations,
  }) : _setPreferredOrientations = setPreferredOrientations;

  static final system = MoviePreviewOrientationCoordinator(
    setPreferredOrientations: SystemChrome.setPreferredOrientations,
  );

  final MoviePreviewPreferredOrientationsSetter _setPreferredOrientations;

  Future<void> _pendingOperation = Future<void>.value();
  MoviePreviewOrientationLease? _owner;

  MoviePreviewOrientationLease acquire() {
    final lease = MoviePreviewOrientationLease._(this);
    _owner = lease;
    lease._locked = _enqueue(() async {
      _ensureOwner(lease);
      await _setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _ensureOwner(lease);
    });
    return lease;
  }

  Future<void> _release(MoviePreviewOrientationLease lease) {
    if (!identical(_owner, lease)) {
      return Future<void>.value();
    }
    _owner = null;
    return _enqueue(() async {
      if (_owner != null) return;
      await _setPreferredOrientations(const []);
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

  void _ensureOwner(MoviePreviewOrientationLease lease) {
    if (!identical(_owner, lease)) {
      throw StateError('Movie preview orientation lease was superseded');
    }
  }
}

class MoviePreviewOrientationLease {
  MoviePreviewOrientationLease._(this._coordinator);

  final MoviePreviewOrientationCoordinator _coordinator;
  late final Future<void> _locked;
  Future<void>? _release;

  Future<void> get locked => _locked;

  Future<void> release() => _release ??= _coordinator._release(this);
}
