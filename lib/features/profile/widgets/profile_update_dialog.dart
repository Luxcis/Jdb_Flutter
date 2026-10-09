import 'package:flutter/material.dart';
import 'package:jade/features/profile/services/update_service.dart';

/// 「安装」按钮的执行结果，由 Screen 编排校验与调起安装器后返回。
enum ApkInstallOutcome {
  /// 哈希校验通过，已调起系统安装器。
  opened,

  /// 哈希校验不一致，已阻止安装并删除已下载文件。
  hashMismatch,

  /// 无法校验哈希（期望值缺失或文件不可读），已阻止安装；文件保留。
  hashUnavailable,

  /// 系统安装器调起失败。
  openFailed,
}

/// 更新弹窗：展示新版本号与更新日志；下载完成后停在完成态，点击「安装」
/// 时由 Screen 校验哈希并在通过后调起系统安装器。
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.result,
    required this.download,
    required this.install,
  });

  final UpdateCheckResult result;

  /// 流式下载选中的 APK，返回本地文件路径。
  final Future<String> Function(
    UpdateCheckResult result,
    void Function(int received, int total) onProgress,
  )
  download;

  /// 点击「安装」时执行的校验与安装编排，返回结果驱动弹窗提示。
  final Future<ApkInstallOutcome> Function(String apkPath) install;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _Phase { idle, downloading, downloaded, verifying }

enum _FailureKind { download, hashMismatch, hashUnavailable, openFailed }

class _UpdateDialogState extends State<UpdateDialog> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String _apkPath = '';
  String? _failureText;
  _FailureKind? _failureKind;

  String get _failureMessage {
    switch (_failureKind) {
      case _FailureKind.download:
        return '下载失败，请重试';
      case _FailureKind.hashMismatch:
        return '安装包校验失败，已阻止安装';
      case _FailureKind.hashUnavailable:
        return '无法校验安装包完整性，已阻止安装';
      case _FailureKind.openFailed:
        return '安装包已下载，请在通知栏/文件管理器中安装';
      case null:
        return '';
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _phase = _Phase.downloading;
      _failureText = null;
      _failureKind = null;
    });
    try {
      final path = await widget.download(widget.result, (received, total) {
        if (total > 0 && mounted) {
          setState(() => _progress = received / total);
        }
      });
      if (!mounted) return;
      setState(() {
        _apkPath = path;
        _phase = _Phase.downloaded;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _failureKind = _FailureKind.download;
          _failureText = _failureMessage;
        });
      }
    }
  }

  Future<void> _startInstall() async {
    if (_phase != _Phase.downloaded) return;
    setState(() {
      _phase = _Phase.verifying;
      _failureText = null;
      _failureKind = null;
    });
    final outcome = await widget.install(_apkPath);
    if (!mounted) return;
    if (outcome == ApkInstallOutcome.opened) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _phase = _Phase.downloaded;
      _failureKind = switch (outcome) {
        ApkInstallOutcome.hashMismatch => _FailureKind.hashMismatch,
        ApkInstallOutcome.hashUnavailable => _FailureKind.hashUnavailable,
        ApkInstallOutcome.openFailed => _FailureKind.openFailed,
        ApkInstallOutcome.opened => null,
      };
      _failureText = _failureMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return AlertDialog(
      title: Text('发现新版本 ${result.latestVersion}'),
      content: SizedBox(
        width: double.maxFinite,
        child: switch (_phase) {
          _Phase.idle => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前版本：', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                SelectableText(
                  result.release.body.isEmpty ? '暂无更新日志' : result.release.body,
                ),
              ],
            ),
          ),
          _Phase.downloading => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 12),
              Text('正在下载更新… ${(_progress * 100).toStringAsFixed(0)}%'),
            ],
          ),
          _Phase.verifying => Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              LinearProgressIndicator(),
              SizedBox(height: 12),
              Text('正在校验安装包完整性…'),
            ],
          ),
          _Phase.downloaded => const Text('下载完成，点击「安装」可开始更新'),
        },
      ),
      actions: [
        ..._buildActionButtons(),
        if (_failureText != null)
          Text(
            '$_failureText',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  List<Widget> _buildActionButtons() {
    switch (_phase) {
      case _Phase.idle:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说'),
          ),
          TextButton(onPressed: _startDownload, child: const Text('立即更新')),
        ];
      case _Phase.downloading:
        return const [TextButton(onPressed: null, child: Text('下载中…'))];
      case _Phase.verifying:
        return const [TextButton(onPressed: null, child: Text('校验中…'))];
      case _Phase.downloaded:
        // 校验不一致时文件已被删除，需重新下载；其他情况保留文件，
        // 允许直接重试校验（无法校验）或重试调起（调起失败）。
        final needsRedownload = _failureKind == _FailureKind.hashMismatch;
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说'),
          ),
          TextButton(
            onPressed: needsRedownload ? _startDownload : _startInstall,
            child: Text(needsRedownload ? '重新下载' : '安装'),
          ),
        ];
    }
  }
}
