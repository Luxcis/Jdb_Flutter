import 'package:flutter/material.dart';

/// 统一的"取消/确定"确认弹窗。
///
/// 各页此前逐份手写 `showDialog<bool>` + AlertDialog，样式与返回值约定集中到此处：
/// 返回 `Future<bool>`（取消/null 均视为 false），调用方只需判断结果。
class ConfirmDialog {
  ConfirmDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String content,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
