import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_operation_manager.dart';
import 'package:jade/features/movie_detail/services/movie_preview_orientation.dart';
import 'package:jade/features/movie_detail/services/movie_preview_system_ui.dart';
import 'package:jade/features/movie_detail/services/movie_preview_wakelock.dart';

void main() {
  test('acquire 同时获取方向与系统栏 lease', () async {
    final orientation = _RecordingOrientationCoordinator();
    final systemUi = _RecordingSystemUiCoordinator();
    final manager = _buildManager(orientation: orientation, systemUi: systemUi);

    final lease = manager.acquire();
    await lease.orientationLocked;

    expect(orientation.calls, [
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    ]);
    expect(systemUi.calls, [
      (mode: SystemUiMode.immersiveSticky, overlays: null),
    ]);
  });

  test('acquireWakelock 在播放开始后启用屏幕常亮', () async {
    final orientation = _RecordingOrientationCoordinator();
    final wakelock = _RecordingWakelockCoordinator();
    final manager = _buildManager(orientation: orientation, wakelock: wakelock);

    final lease = manager.acquire();
    await lease.orientationLocked;
    manager.acquireWakelock(lease);
    await pumpEventQueue();

    expect(wakelock.calls, [true]);
  });

  test('release 释放所有设备状态', () async {
    final orientation = _RecordingOrientationCoordinator();
    final wakelock = _RecordingWakelockCoordinator();
    final systemUi = _RecordingSystemUiCoordinator();
    final manager = _buildManager(
      orientation: orientation,
      wakelock: wakelock,
      systemUi: systemUi,
    );

    final lease = manager.acquire();
    await lease.orientationLocked;
    manager.acquireWakelock(lease);
    await pumpEventQueue();
    await manager.release();

    expect(orientation.calls.last, isEmpty);
    expect(wakelock.calls, [true, false]);
    expect(systemUi.calls.last.mode, SystemUiMode.manual);
  });

  test('方向锁定失败时仍保持系统栏，release 时恢复', () async {
    final orientation = _FailingOrientationCoordinator();
    final systemUi = _RecordingSystemUiCoordinator();
    final manager = _buildManager(orientation: orientation, systemUi: systemUi);

    final lease = manager.acquire();
    await expectLater(lease.orientationLocked, throwsA(isA<StateError>()));
    expect(systemUi.calls, [
      (mode: SystemUiMode.immersiveSticky, overlays: null),
    ]);

    await manager.release();
    expect(systemUi.calls.last.mode, SystemUiMode.manual);
  });

  test('replaceOrientationLease 替换方向 lease 并保留系统栏/wakelock', () async {
    final orientation = _RecordingOrientationCoordinator();
    final systemUi = _RecordingSystemUiCoordinator();
    final wakelock = _RecordingWakelockCoordinator();
    final manager = _buildManager(
      orientation: orientation,
      systemUi: systemUi,
      wakelock: wakelock,
    );

    final lease = manager.acquire();
    await lease.orientationLocked;
    manager.acquireWakelock(lease);
    await pumpEventQueue();

    final newLease = manager.replaceOrientationLease(lease);
    await newLease.orientationLocked;

    // 单所有者协调器在旧 lease 释放前已获取新 lease，
    // 因此旧 lease 的恢复操作被抑制，方向始终保持在横屏。
    expect(orientation.calls, [
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    ]);
    expect(systemUi.calls.length, 1);
    expect(wakelock.calls, [true]);
  });

  test('重叠页面场景下旧 manager 的迟到 release 不覆盖新状态', () async {
    final orientation = _RecordingOrientationCoordinator();
    final systemUi = _RecordingSystemUiCoordinator();
    final manager = _buildManager(orientation: orientation, systemUi: systemUi);

    final leaseA = manager.acquire();
    await leaseA.orientationLocked;

    final releaseA = manager.release();
    final leaseB = manager.acquire();
    await leaseB.orientationLocked;

    await releaseA;

    expect(orientation.calls.last, [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    expect(
      systemUi.calls
          .where((c) => c.mode == SystemUiMode.immersiveSticky)
          .length,
      2,
    );
  });
}

MoviePreviewOperationManager _buildManager({
  required MoviePreviewOrientationCoordinator orientation,
  MoviePreviewWakelockCoordinator? wakelock,
  MoviePreviewSystemUiCoordinator? systemUi,
}) {
  return MoviePreviewOperationManager(
    orientationCoordinator: orientation,
    wakelockCoordinator: wakelock ?? _NoOpWakelockCoordinator(),
    systemUiCoordinator: systemUi ?? _NoOpSystemUiCoordinator(),
  );
}

class _NoOpWakelockCoordinator extends MoviePreviewWakelockCoordinator {
  _NoOpWakelockCoordinator() : super(setWakelockEnabled: (_) async {});
}

class _NoOpSystemUiCoordinator extends MoviePreviewSystemUiCoordinator {
  _NoOpSystemUiCoordinator() : super(setSystemUiMode: (_, {overlays}) async {});
}

class _RecordingOrientationCoordinator
    extends MoviePreviewOrientationCoordinator {
  factory _RecordingOrientationCoordinator() {
    final calls = <List<DeviceOrientation>>[];
    return _RecordingOrientationCoordinator._(
      calls,
      setPreferredOrientations: (orientations) async {
        calls.add(List.of(orientations));
      },
    );
  }

  _RecordingOrientationCoordinator._(
    this.calls, {
    required super.setPreferredOrientations,
  });

  final List<List<DeviceOrientation>> calls;
}

class _RecordingWakelockCoordinator extends MoviePreviewWakelockCoordinator {
  factory _RecordingWakelockCoordinator() {
    final calls = <bool>[];
    return _RecordingWakelockCoordinator._(
      calls,
      setWakelockEnabled: (enabled) async => calls.add(enabled),
    );
  }

  _RecordingWakelockCoordinator._(
    this.calls, {
    required super.setWakelockEnabled,
  });

  final List<bool> calls;
}

class _RecordingSystemUiCoordinator extends MoviePreviewSystemUiCoordinator {
  factory _RecordingSystemUiCoordinator() {
    final calls = <({SystemUiMode mode, List<SystemUiOverlay>? overlays})>[];
    return _RecordingSystemUiCoordinator._(
      calls,
      setSystemUiMode: (mode, {overlays}) async {
        calls.add((mode: mode, overlays: overlays));
      },
    );
  }

  _RecordingSystemUiCoordinator._(this.calls, {required super.setSystemUiMode});

  final List<({SystemUiMode mode, List<SystemUiOverlay>? overlays})> calls;
}

class _FailingOrientationCoordinator
    extends MoviePreviewOrientationCoordinator {
  _FailingOrientationCoordinator()
    : super(
        setPreferredOrientations: (_) async {
          throw StateError('orientation lock failed');
        },
      );
}
