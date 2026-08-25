import 'package:flutter/material.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/utils/github_proxy.dart';

/// 线路选择底部弹窗：自动 + 各域名单选行。
class LinePickerSheet extends StatelessWidget {
  const LinePickerSheet({
    super.key,
    required this.domainManager,
    required this.onSelected,
  });

  final DomainManager domainManager;
  final void Function(String? url) onSelected;

  @override
  Widget build(BuildContext context) {
    final dm = domainManager;
    final domains = dm.apiDomains.isNotEmpty
        ? dm.apiDomains
        : const [AppConstants.fallbackBaseUrl];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '线路选择',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const Text('自动（推荐）'),
              subtitle: const Text('请求失败时自动切换可用线路'),
              trailing: dm.isAutoMode ? const Icon(Icons.check) : null,
              onTap: () => onSelected('auto'),
            ),
            const Divider(height: 1),
            for (final url in domains)
              ListTile(
                title: Text(hostOf(url)),
                trailing: !dm.isAutoMode && dm.currentUrl == url
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => onSelected(url),
              ),
          ],
        ),
      ),
    );
  }
}

const githubProxyOptions = [
  'https://hub.luxcis.top/',
  'https://gh-proxy.com/',
];

/// GitHub 代理对应的展示文案。
String githubProxyLabel(String proxy) {
  if (proxy.isEmpty) return '不使用代理';
  return proxy
      .replaceFirst(RegExp(r'^https?://'), '')
      .replaceFirst(RegExp(r'/$'), '');
}

/// GitHub 代理选择底部弹窗：不使用 + 内置选项 + 自定义。
class GithubProxyPickerSheet extends StatelessWidget {
  const GithubProxyPickerSheet({super.key, required this.settingsProvider});

  final SettingsProvider settingsProvider;

  Future<void> _selectCustom(BuildContext sheetContext) async {
    final value = await showDialog<String>(
      context: sheetContext,
      builder: (dialogContext) => CustomProxyDialog(
        initialValue: settingsProvider.githubProxy,
      ),
    );
    if (value == null) return;
    final normalized = normalizeGithubProxy(value.trim());
    if (normalized.isEmpty) return;
    await settingsProvider.setGithubProxy(normalized);
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  @override
  Widget build(BuildContext context) {
    final current = settingsProvider.githubProxy;
    final isCustom =
        current.isNotEmpty && !githubProxyOptions.contains(current);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'GitHub 代理',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text('不使用代理'),
            trailing: current.isEmpty ? const Icon(Icons.check) : null,
            onTap: () {
              settingsProvider.setGithubProxy('');
              Navigator.pop(context);
            },
          ),
          for (final proxy in githubProxyOptions)
            ListTile(
              title: Text(proxy),
              trailing: current == proxy ? const Icon(Icons.check) : null,
              onTap: () {
                settingsProvider.setGithubProxy(proxy);
                Navigator.pop(context);
              },
            ),
          ListTile(
            title: const Text('自定义…'),
            trailing: isCustom ? const Icon(Icons.check) : null,
            onTap: () => _selectCustom(context),
          ),
        ],
      ),
    );
  }
}

/// 自定义 GitHub 代理输入弹窗：确定后以规范化的值弹出。
class CustomProxyDialog extends StatefulWidget {
  const CustomProxyDialog({super.key, required this.initialValue});

  final String initialValue;

  @override
  State<CustomProxyDialog> createState() => _CustomProxyDialogState();
}

class _CustomProxyDialogState extends State<CustomProxyDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = '请输入代理地址');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义 GitHub 代理'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        decoration: InputDecoration(
          hintText: 'https://example.com/mirror/',
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 外观模式的展示文案。
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟随系统',
  ThemeMode.light => '浅色模式',
  ThemeMode.dark => '深色模式',
};

/// 去掉 URL 的协议前缀，仅显示 host。
String hostOf(String url) => url.replaceFirst(RegExp(r'^https?://'), '');
