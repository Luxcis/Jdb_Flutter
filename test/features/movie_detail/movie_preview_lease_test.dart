import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_lease.dart';

void main() {
  test('lease 进入与退出操作按 FIFO 顺序执行', () async {
    final calls = <String>[];
    final coordinator = _TestCoordinator(
      onEnable: () async => calls.add('enable'),
      onDisable: () async => calls.add('disable'),
    );

    final lease = coordinator.acquire();
    await lease.enabled;
    await lease.release();

    expect(calls, ['enable', 'disable']);
  });

  test('release 在 enable 完成前排队在 enable 之后执行', () async {
    final enableStarted = Completer<void>();
    final allowEnable = Completer<void>();
    final calls = <String>[];
    final coordinator = _TestCoordinator(
      onEnable: () async {
        calls.add('enable-start');
        enableStarted.complete();
        await allowEnable.future;
        calls.add('enable-end');
      },
      onDisable: () async => calls.add('disable'),
    );

    final lease = coordinator.acquire();
    final release = lease.release();
    await enableStarted.future;
    expect(calls, ['enable-start']);
    allowEnable.complete();
    await release;
    expect(calls, ['enable-start', 'enable-end', 'disable']);
  });

  test('旧 lease 被取代后其 release 不再触发 disable', () async {
    final calls = <String>[];
    final coordinator = _TestCoordinator(
      onEnable: () async => calls.add('enable'),
      onDisable: () async => calls.add('disable'),
    );

    final first = coordinator.acquire();
    await first.enabled;
    final second = coordinator.acquire();
    await second.enabled;

    await first.release();
    expect(calls.where((c) => c == 'disable'), isEmpty);

    await second.release();
    expect(calls.where((c) => c == 'disable').length, 1);
  });

  test('单个 lease 的 release 幂等', () async {
    final calls = <String>[];
    final coordinator = _TestCoordinator(
      onEnable: () async => calls.add('enable'),
      onDisable: () async => calls.add('disable'),
    );

    final lease = coordinator.acquire();
    await lease.enabled;
    await lease.release();
    await lease.release();

    expect(calls.where((c) => c == 'disable').length, 1);
  });

  test('enable 失败后 release 仍尝试恢复', () async {
    final calls = <String>[];
    final coordinator = _TestCoordinator(
      onEnable: () async {
        calls.add('enable');
        throw StateError('enable failed');
      },
      onDisable: () async => calls.add('disable'),
    );

    final lease = coordinator.acquire();
    await expectLater(lease.enabled, throwsA(isA<StateError>()));
    await lease.release();

    expect(calls, ['enable', 'disable']);
  });

  test('disable 失败不阻塞后续操作', () async {
    final calls = <String>[];
    final coordinator = _TestCoordinator(
      onEnable: () async => calls.add('enable'),
      onDisable: () async {
        calls.add('disable');
        throw StateError('disable failed');
      },
    );

    final lease = coordinator.acquire();
    await lease.enabled;
    // release 可能抛出错误，但应由调用方决定如何处理；
    // 关键是不会阻塞队列中后续操作。
    unawaited(lease.release().catchError((Object _) {}));

    final lease2 = coordinator.acquire();
    await lease2.enabled;
    expect(calls, ['enable', 'disable', 'enable']);
  });
}

class _TestCoordinator extends MoviePreviewLeaseCoordinator {
  _TestCoordinator({
    required Future<void> Function() onEnable,
    required Future<void> Function() onDisable,
  }) : _onEnable = onEnable,
       _onDisable = onDisable;

  final Future<void> Function() _onEnable;
  final Future<void> Function() _onDisable;
  _TestLease? _owner;

  @override
  MoviePreviewLease createLease() => _TestLease._(this);

  @override
  void onAcquire(MoviePreviewLease lease) => _owner = lease as _TestLease;

  @override
  bool isOwned(MoviePreviewLease lease) => identical(_owner, lease);

  @override
  void onRelease(MoviePreviewLease lease) => _owner = null;

  @override
  Future<void> onEnable(MoviePreviewLease lease) => _onEnable();

  @override
  Future<void> onDisable(MoviePreviewLease lease) => _onDisable();

  _TestLease acquire() => acquireLease() as _TestLease;
}

class _TestLease extends MoviePreviewLease {
  _TestLease._(_TestCoordinator super.coordinator);
}
