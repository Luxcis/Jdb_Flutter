import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_orientation.dart';

void main() {
  test('旧 lease 延迟恢复完成后新 lease 最终保持横屏', () async {
    final restoreStarted = Completer<void>();
    final allowRestoreToFinish = Completer<void>();
    final orientationCalls = <List<DeviceOrientation>>[];
    final coordinator = MoviePreviewOrientationCoordinator(
      setPreferredOrientations: (orientations) async {
        orientationCalls.add(List.of(orientations));
        if (orientations.isEmpty && !restoreStarted.isCompleted) {
          restoreStarted.complete();
          await allowRestoreToFinish.future;
        }
      },
    );

    final leaseA = coordinator.acquire();
    await leaseA.locked;

    final releaseA = leaseA.release();
    await restoreStarted.future;

    final leaseB = coordinator.acquire();
    var leaseBLocked = false;
    unawaited(leaseB.locked.then((_) => leaseBLocked = true));
    await Future<void>.delayed(Duration.zero);
    expect(leaseBLocked, isFalse);

    allowRestoreToFinish.complete();
    await releaseA;
    await leaseB.locked;

    expect(orientationCalls, [
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      <DeviceOrientation>[],
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    ]);

    await leaseA.release();
    expect(orientationCalls, hasLength(3));

    await leaseB.release();
    expect(orientationCalls.last, isEmpty);
  });
}
