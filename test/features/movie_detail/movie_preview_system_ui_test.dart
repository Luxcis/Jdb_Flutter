import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_system_ui.dart';

class _RecordingSetter {
  final calls = <({SystemUiMode mode, List<SystemUiOverlay>? overlays})>[];

  Future<void> call(
    SystemUiMode mode, {
    List<SystemUiOverlay>? overlays,
  }) async {
    calls.add((mode: mode, overlays: overlays));
  }
}

void main() {
  test('acquire 设置沉浸模式', () async {
    final setter = _RecordingSetter();
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: setter.call,
    );

    final lease = coordinator.acquire();
    await lease.enabled;

    expect(setter.calls, [
      (mode: SystemUiMode.immersiveSticky, overlays: null),
    ]);
    await lease.release();
  });

  test('release 恢复默认双栏', () async {
    final setter = _RecordingSetter();
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: setter.call,
    );

    final lease = coordinator.acquire();
    await lease.enabled;
    await lease.release();

    expect(setter.calls.last.mode, SystemUiMode.manual);
    expect(setter.calls.last.overlays, [
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);
  });

  test('旧 lease 被取代后，其迟到释放不触发恢复', () async {
    final setter = _RecordingSetter();
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: setter.call,
    );

    final first = coordinator.acquire();
    await first.enabled;
    final second = coordinator.acquire();
    await second.enabled;

    await first.release();
    expect(setter.calls.length, 2);

    await second.release();
    expect(setter.calls.length, 3);
    expect(setter.calls.last.mode, SystemUiMode.manual);
  });

  test('release 在 acquire 完成前排队，顺序为进入后退出', () async {
    final setter = _RecordingSetter();
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: setter.call,
    );

    final lease = coordinator.acquire();
    await lease.release();

    expect(setter.calls.first.mode, SystemUiMode.immersiveSticky);
    expect(setter.calls.last.mode, SystemUiMode.manual);
  });

  test('acquire 失败后 release 仍执行恢复', () async {
    var failEnter = true;
    final setter = _RecordingSetter();
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: (mode, {overlays}) async {
        if (failEnter && mode == SystemUiMode.immersiveSticky) {
          throw StateError('set failed');
        }
        await setter.call(mode, overlays: overlays);
      },
    );

    final lease = coordinator.acquire();
    await expectLater(lease.enabled, throwsA(isA<StateError>()));

    failEnter = false;
    await lease.release();

    expect(setter.calls.single.mode, SystemUiMode.manual);
  });
}
