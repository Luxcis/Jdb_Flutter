import 'dart:async';

/// 一个串行操作队列，保证进入/退出操作按 FIFO 顺序执行，
/// 且任一操作失败不会阻塞后续操作。
class _SerialOperationQueue {
  Future<void> _pending = Future<void>.value();

  Future<void> enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

/// 单个设备状态所有权的 lease。
///
/// [enabled] 完成时表示进入操作已执行（可能以错误完成）。
/// [release] 幂等地归还所有权并触发恢复操作。
abstract class MoviePreviewLease {
  MoviePreviewLease(this.coordinator);

  final MoviePreviewLeaseCoordinator coordinator;
  Future<void>? _enabled;
  Future<void>? _releaseOperation;

  Future<void> get enabled => _enabled!;

  Future<void> release() => _releaseOperation ??= coordinator._release(this);
}

/// 通用 lease 协调器，集中管理串行队列与 lease 所有权。
///
/// 子类只需定义：
/// - 如何创建 lease（[createLease]）
/// - 所有权模型（[onAcquire] / [isOwned] / [onRelease]）
/// - 进入/退出时实际执行的设备操作（[onEnable] / [onDisable]）
abstract class MoviePreviewLeaseCoordinator {
  final _SerialOperationQueue _queue = _SerialOperationQueue();

  MoviePreviewLease acquireLease() {
    final lease = createLease();
    onAcquire(lease);
    lease._enabled = _queue.enqueue(() => onEnable(lease));
    return lease;
  }

  Future<void> _release(MoviePreviewLease lease) {
    if (!isOwned(lease)) {
      return Future<void>.value();
    }
    onRelease(lease);
    return _queue.enqueue(() => onDisable(lease));
  }

  MoviePreviewLease createLease();
  void onAcquire(MoviePreviewLease lease);
  bool isOwned(MoviePreviewLease lease);
  void onRelease(MoviePreviewLease lease);
  Future<void> onEnable(MoviePreviewLease lease);
  Future<void> onDisable(MoviePreviewLease lease);
}
