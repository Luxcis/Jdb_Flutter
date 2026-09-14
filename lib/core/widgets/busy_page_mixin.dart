import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 收藏/列表类页面的公共脚手架能力：
/// 全屏 busy 遮罩、SnackBar 提示与「失败记日志并提示后中止」的守卫操作。
///
/// 页面 State 通过 `with [BusyPageState]` 复用，消除各页逐字重复的
/// 遮罩样式与 `_showMessage` 样板。
mixin BusyPageState<T extends StatefulWidget> on State<T> {
  /// 页面级互斥忙状态：任一写操作进行时显示遮罩。
  final ValueNotifier<bool> _busy = ValueNotifier(false);

  /// 供 build 中监听（如全页遮罩的显隐）。
  ValueListenable<bool> get busyListenable => _busy;

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  bool get busy => _busy.value;
  set busy(bool value) => _busy.value = value;

  /// 全屏半透明 busy 遮罩；[absorb] 为 true 时同时拦截输入。
  Widget busyOverlay({bool absorb = false}) => Positioned.fill(
    child: absorb
        ? const AbsorbPointer(
            child: ColoredBox(
              color: Color(0x73000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        : const ColoredBox(
            color: Color(0x73000000),
            child: Center(child: CircularProgressIndicator()),
          ),
  );

  void showPageMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 执行一次写操作：busy 置位、失败记日志并提示 [failureMessage] 后中止；
  /// 成功时执行 [onSuccess]；始终复位 busy。返回是否成功。
  ///
  /// 提示回调都在 mounted 保护下执行。
  Future<bool> runBusyOperation({
    required String logName,
    required String failureMessage,
    required Future<void> Function() operation,
    VoidCallback? onSuccess,
  }) async {
    if (busy) return false;
    busy = true;
    try {
      try {
        await operation();
      } catch (error, stackTrace) {
        developer.log(failureMessage, name: logName, error: error, stackTrace: stackTrace);
        if (!mounted) return false;
        showPageMessage(failureMessage);
        return false;
      }
      if (!mounted) return false;
      onSuccess?.call();
      return true;
    } finally {
      if (mounted) {
        _busy.value = false;
      }
    }
  }
}
