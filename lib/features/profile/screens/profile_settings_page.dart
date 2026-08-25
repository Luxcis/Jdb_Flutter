import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/cache_service.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/features/profile/services/app_version_service.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';
import 'package:jade/features/profile/services/update_service.dart';
import 'package:jade/features/profile/widgets/profile_pickers.dart';
import 'package:jade/features/profile/widgets/profile_update_dialog.dart';
import 'package:jade/features/profile/widgets/token_authentication_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({
    super.key,
    this.cacheService,
    this.appVersionService,
    this.tokenAuthenticationService,
  });

  final CacheService? cacheService;
  final AppVersionService? appVersionService;
  final TokenAuthenticationService? tokenAuthenticationService;

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  static const _tokenTapWindow = Duration(seconds: 2);

  late final CacheService _cacheService;
  late final AppVersionService _appVersionService;
  Timer? _tokenTapTimer;
  var _versionTapCount = 0;
  int? _cacheSizeBytes;
  String _appVersion = '…';
  var _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _cacheService = widget.cacheService ?? JdbImageCacheService();
    _appVersionService =
        widget.appVersionService ?? const PackageAppVersionService();
    unawaited(_loadCacheSize());
    unawaited(_loadAppVersion());
  }

  void _onVersionTap() {
    if (_versionTapCount == 0) {
      _tokenTapTimer = Timer(_tokenTapWindow, _resetVersionTapCount);
    }
    _versionTapCount++;
    if (_versionTapCount < 5) return;
    _resetVersionTapCount();
    unawaited(_openTokenAuthenticationDialog());
  }

  void _resetVersionTapCount() {
    _tokenTapTimer?.cancel();
    _tokenTapTimer = null;
    _versionTapCount = 0;
  }

  Future<void> _openTokenAuthenticationDialog() async {
    final auth = context.read<AuthProvider>();
    final service =
        widget.tokenAuthenticationService ??
        ApiTokenAuthenticationService(ApiClient.instance);
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TokenAuthenticationDialog(
        authenticate: service.authenticate,
        saveSession: auth.login,
      ),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('认证 Token 已更新')));
    }
  }

  @override
  void dispose() {
    _tokenTapTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCacheSize() async {
    final size = await _cacheService.getCacheSizeBytes();
    if (!mounted) return;
    setState(() => _cacheSizeBytes = size);
  }

  Future<void> _loadAppVersion() async {
    try {
      final version = await _appVersionService.loadVersion();
      if (!mounted) return;
      setState(() {
        _appVersion = version;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersion = '未知');
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final proxy = context.read<SettingsProvider>().githubProxy;
      final checker = UpdateChecker(
        currentVersion: _appVersion == '…' ? '0.0.0' : _appVersion,
        proxy: proxy,
      );
      final result = await checker.check();
      if (!mounted) return;
      if (!result.hasUpdate) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已是最新版本')));
        return;
      }
      await _showUpdateDialog(result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('检查更新失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _showUpdateDialog(UpdateCheckResult result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        result: result,
        install: _downloadAndInstall,
      ),
    );
  }

  /// 下载选中 ABI 的 APK 并调起系统安装器；进度通过 onProgress 上报。
  Future<void> _downloadAndInstall(
    UpdateCheckResult result,
    void Function(int received, int total) onProgress,
  ) async {
    final proxy = context.read<SettingsProvider>().githubProxy;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final installer = UpdateInstaller(proxy: proxy);
    final asset = installer.pickAsset(
      result.release,
      deviceInfo.supportedAbis,
    );
    final path = await installer.download(asset, onProgress: onProgress);
    if (!mounted) return;
    final opened = await OpenFilex.open(path);
    if (!mounted) return;
    if (opened.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('安装包已下载，请在通知栏/文件管理器中安装')),
      );
    }
  }

  Future<void> _confirmAndClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除图片缓存？'),
        content: const Text('将删除已下载的图片封面与剧照。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _cacheService.clearAll();
      if (!mounted) return;
      setState(() => _cacheSizeBytes = 0);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缓存已清除')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('清除失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final blurMovieImages = context.select<SettingsProvider, bool>(
      (settings) => settings.blurMovieImages,
    );
    final githubProxy = context.select<SettingsProvider, String>(
      (s) => s.githubProxy,
    );
    final dm = context.watch<DomainManager>();
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final cells = <Widget>[
      ListTile(
        leading: const Icon(Icons.brightness_6_outlined),
        title: const Text('外观模式'),
        subtitle: Text(themeModeLabel(themeMode)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openAppearancePicker(context),
      ),
      SwitchListTile(
        secondary: const Icon(Icons.blur_on_outlined),
        title: const Text('影片图片模糊'),
        subtitle: const Text('模糊影片封面与剧照'),
        value: blurMovieImages,
        onChanged: context.read<SettingsProvider>().setBlurMovieImages,
      ),
      ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: const Text('线路选择'),
        subtitle: Text(dm.isAutoMode ? '自动' : hostOf(dm.currentUrl)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openLinePicker(context),
      ),
      ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: const Text('清除缓存'),
        subtitle: Text(
          _cacheSizeBytes == null ? '计算中…' : formatCacheSize(_cacheSizeBytes!),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _confirmAndClearCache,
      ),
      ListTile(
        leading: const Icon(Icons.public),
        title: const Text('GitHub 代理'),
        subtitle: Text(githubProxyLabel(githubProxy)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openGithubProxyPicker(context),
      ),
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('当前版本'),
        subtitle: Text(_appVersion),
        trailing: TextButton(
          onPressed: _checkingUpdate ? null : _checkForUpdate,
          child: _checkingUpdate
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('检查更新'),
        ),
        onTap: _onVersionTap,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView.separated(
        itemCount: cells.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) => cells[index],
      ),
    );
  }

  /// 弹出外观模式选择弹窗；选中后立即生效并持久化。
  void _openAppearancePicker(BuildContext context) {
    final theme = context.read<ThemeProvider>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '外观模式',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(themeModeLabel(mode)),
                trailing: theme.themeMode == mode
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  theme.setThemeMode(mode);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 弹出线路选择弹窗；选中后立即生效并提示。
  void _openLinePicker(BuildContext context) {
    final dm = context.read<DomainManager>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => LinePickerSheet(
        domainManager: dm,
        onSelected: (String? url) {
          if (url == null) return;
          final isAuto = url == 'auto';
          if (isAuto) {
            unawaited(dm.selectAuto());
          } else {
            unawaited(dm.select(url));
          }
          ApiClient.instance.swapBaseUrl(dm.currentUrl);
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAuto ? '已切换到自动线路' : '已切换到 ${hostOf(url)}'),
            ),
          );
        },
      ),
    );
  }

  /// 弹出 GitHub 代理选择弹窗；选中后立即生效并持久化。
  void _openGithubProxyPicker(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => GithubProxyPickerSheet(
        settingsProvider: settingsProvider,
      ),
    );
  }
}
