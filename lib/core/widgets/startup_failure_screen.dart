import 'package:flutter/material.dart';

import 'error_retry_widget.dart';

/// 启动初始化失败兜底页：展示原因并提供重试，替代失败时的永久白屏。
///
/// 重试回调由启动入口注入，重跑初始化成功后的 runApp 由入口闭环。
class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: ErrorRetryWidget(
            message: '启动初始化失败：$error',
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}
