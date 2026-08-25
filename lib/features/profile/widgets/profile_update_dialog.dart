import 'package:flutter/material.dart';
import 'package:jade/features/profile/services/update_service.dart';

/// 更新弹窗：展示新版本号与更新日志，支持下载安装。
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.result, required this.install});

  final UpdateCheckResult result;
  final Future<void> Function(
    UpdateCheckResult result,
    void Function(int received, int total) onProgress,
  ) install;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  bool _finished = false;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await widget.install(widget.result, (received, total) {
        if (total > 0 && mounted) {
          setState(() => _progress = received / total);
        }
      });
      if (!mounted) return;
      setState(() => _finished = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '下载失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return AlertDialog(
      title: Text('发现新版本 ${result.latestVersion}'),
      content: SizedBox(
        width: double.maxFinite,
        child: _downloading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 12),
                  Text(
                    '正在下载更新… ${(_progress * 100).toStringAsFixed(0)}%',
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前版本：',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      result.release.body.isEmpty
                          ? '暂无更新日志'
                          : result.release.body,
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        if (!_downloading && !_finished)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说'),
          ),
        if (_error != null)
          Text(
            '$_error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_downloading)
          const TextButton(
            onPressed: null,
            child: Text('下载中…'),
          )
        else
          TextButton(
            onPressed: _finished ? () => Navigator.pop(context) : _startDownload,
            child: Text(_finished ? '完成' : '立即更新'),
          ),
      ],
    );
  }
}
