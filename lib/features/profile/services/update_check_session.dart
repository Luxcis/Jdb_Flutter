import 'package:flutter/foundation.dart';

/// 检查更新结论的会话级状态：仅内存存活，随应用进程结束而消失。
enum UpdateCheckStatus {
  /// 本应用运行内尚未完成过一次检查（或尚未得到结论）。
  none,

  /// 最新一次成功检查的结论为「已是最新版」。
  upToDate,

  /// 最新一次成功检查的结论为「有新版本」。
  hasUpdate,
}

/// 应用运行周期内的检查更新结论记录。
///
/// 单次检查的结论只在当前进程内保持：离开设置页不重置；进程重启后重新
/// 变为 [UpdateCheckStatus.none]，不持久化到任何存储。
class UpdateCheckSession extends ChangeNotifier {
  /// 创建独立实例（测试或多容器场景）；常规入口是 [shared]。
  UpdateCheckSession();

  /// 进程级共享实例：整个应用生命周期内唯一，随进程结束而消失。
  static final UpdateCheckSession shared = UpdateCheckSession();

  UpdateCheckStatus _status = UpdateCheckStatus.none;

  UpdateCheckStatus get status => _status;

  /// 记录一次成功检查的结论；新结论覆盖旧结论。
  void record(bool hasUpdate) {
    final next = hasUpdate
        ? UpdateCheckStatus.hasUpdate
        : UpdateCheckStatus.upToDate;
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }
}
