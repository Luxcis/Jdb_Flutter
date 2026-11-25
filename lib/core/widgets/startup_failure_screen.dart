import 'package:flutter/material.dart';
import 'package:jade/core/utils/user_facing_error.dart';

import 'error_retry_widget.dart';

/// 启动初始化失败兜底页：展示原因并提供重试，替代失败时的永久白屏。
///
/// 重试回调由启动入口注入，重跑初始化成功后的 runApp 由入口闭环。
class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({
    super.key,
    required this.error,
    required this.onRetry,
    this.retryable = true,
  });

  final Object error;
  final VoidCallback onRetry;

  /// 本地数据/配置类错误重试同一初始化流程通常无意义，提示用户重启或清理数据；
  /// 网络类错误仍按可重试处理。
  final bool retryable;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: ErrorRetryWidget(
            // 原始异常只进日志；页面统一展示中文可读文案。
            message: retryable
                ? '启动初始化失败：${userFacingErrorMessage(error)}'
                : '启动初始化失败：本地数据异常，请重启应用；若仍失败请清除应用数据后重试',
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}
