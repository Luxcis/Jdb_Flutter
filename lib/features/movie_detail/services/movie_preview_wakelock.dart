import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';

typedef MoviePreviewWakelockSetter = Future<void> Function(bool enabled);

/// Coordinates screen-awake ownership across overlapping preview pages.
///
/// Every acquired lease keeps the wakelock owned. Releasing an older lease
/// cannot disable the wakelock while another preview page still owns a lease.
class MoviePreviewWakelockCoordinator {
  MoviePreviewWakelockCoordinator({
    required MoviePreviewWakelockSetter setWakelockEnabled,
  }) : _setWakelockEnabled = setWakelockEnabled;

  static final system = MoviePreviewWakelockCoordinator(
    setWakelockEnabled: (enabled) =>
        enabled ? WakelockPlus.enable() : WakelockPlus.disable(),
  );

  final MoviePreviewWakelockSetter _setWakelockEnabled;
  final _owners = <MoviePreviewWakelockLease>{};
  Future<void> _pendingOperation = Future<void>.value();

  MoviePreviewWakelockLease acquire() {
    final lease = MoviePreviewWakelockLease._(this);
    _owners.add(lease);
    lease._enabled = _enqueue(() async {
      if (!_owners.contains(lease)) return;
      await _setWakelockEnabled(true);
    });
    return lease;
  }

  Future<void> _release(MoviePreviewWakelockLease lease) {
    if (!_owners.remove(lease)) {
      return Future<void>.value();
    }
    return _enqueue(() async {
      if (_owners.isNotEmpty) return;
      await _setWakelockEnabled(false);
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
}

/// A single preview page's idempotent screen-awake ownership handle.
class MoviePreviewWakelockLease {
  MoviePreviewWakelockLease._(this._coordinator);

  final MoviePreviewWakelockCoordinator _coordinator;
  late final Future<void> _enabled;
  Future<void>? _releaseOperation;

  Future<void> get enabled => _enabled;

  Future<void> release() => _releaseOperation ??= _coordinator._release(this);
}
