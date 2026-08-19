import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/cache_service.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/filter_drawer.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/movie_list_tile.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/app_version_service.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';
import 'package:jade/features/profile/services/update_service.dart';
import 'package:jade/features/profile/widgets/token_authentication_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

class ProfileMovieCollectionPage extends StatefulWidget {
  const ProfileMovieCollectionPage({
    super.key,
    required this.title,
    this.filterButton = false,
  });

  final String title;
  final bool filterButton;

  @override
  State<ProfileMovieCollectionPage> createState() =>
      _ProfileMovieCollectionPageState();
}

class _ProfileMovieCollectionPageState extends State<ProfileMovieCollectionPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final PaginationController<MovieSummary> _controller;
  static const _tabs = ['全部', '有码', '无码', '欧美', 'FC2', '动漫'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _controller = PaginationController<MovieSummary>(
      fetch: (page) async =>
          const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
    )..fetchMore();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.filterButton)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.filter_list),
                tooltip: '筛选',
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      endDrawer: const FilterDrawer(
        schema: FilterSchema(
          groups: [
            FilterGroup(
              label: '状态',
              items: [
                (label: '全部', value: 'all'),
                (label: '可播放', value: 'playable'),
                (label: '含磁链', value: 'magnet'),
                (label: '字幕', value: 'subtitle'),
              ],
            ),
          ],
        ),
        onChanged: _noopFilter,
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((_) => MovieGridView(controller: _controller))
            .toList(growable: false),
      ),
    );
  }
}

class ProfileFollowingPage extends StatefulWidget {
  const ProfileFollowingPage({super.key});

  @override
  State<ProfileFollowingPage> createState() => _ProfileFollowingPageState();
}

class _ProfileFollowingPageState extends State<ProfileFollowingPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['全部关注', '演员', '标签'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的关注'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabs
            .map(
              (_) => ListView.builder(
                itemCount: 0,
                itemBuilder: (_, i) => MovieListTile(
                  movie: MovieSummary(
                    id: '$i',
                    number: '-',
                    title: '-',
                    coverUrl: '',
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class ProfileFavoritesPage extends StatelessWidget {
  const ProfileFavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _CellScaffold(
      title: '我的收藏',
      cells: [
        _ProfileCell(
          title: '收藏的演员',
          icon: Icons.person_outline,
          route: AppRoutes.profileFavoritesActors,
        ),
        _ProfileCell(
          title: '收藏的片商',
          icon: Icons.business,
          route: AppRoutes.profileFavoritesMakers,
        ),
        _ProfileCell(
          title: '收藏的系列',
          icon: Icons.collections_bookmark,
          route: AppRoutes.profileFavoritesSeries,
        ),
        _ProfileCell(
          title: '收藏的导演',
          icon: Icons.person_search,
          route: AppRoutes.profileFavoritesDirectors,
        ),
        _ProfileCell(
          title: '收藏的番号',
          icon: Icons.confirmation_number_outlined,
          route: AppRoutes.profileFavoritesCodes,
        ),
        _ProfileCell(
          title: '清单',
          subtitle: '0部影片，被查看0次',
          icon: Icons.list_alt,
          route: AppRoutes.profileFavoritesLists,
        ),
      ],
    );
  }
}

class ProfileFavoriteActorsPage extends StatefulWidget {
  const ProfileFavoriteActorsPage({super.key});

  @override
  State<ProfileFavoriteActorsPage> createState() =>
      _ProfileFavoriteActorsPageState();
}

class _ProfileFavoriteActorsPageState extends State<ProfileFavoriteActorsPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final PaginationController<ActorSummary> _controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _controller = PaginationController<ActorSummary>(
      fetch: (page) async =>
          const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
    )..fetchMore();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tabs = ['全部', '有码', '无码', '欧美'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏的演员'),
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabs
            .map((_) => ActorGridView(controller: _controller))
            .toList(growable: false),
      ),
    );
  }
}

class ProfileNamedCollectionPage extends StatelessWidget {
  const ProfileNamedCollectionPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _CellScaffold(
      title: title,
      cells: List.generate(
        6,
        (i) => _ProfileCell(
          title: '$title ${i + 1}',
          subtitle: title.contains('清单') || title == '我的清单'
              ? '0部影片，被查看0次'
              : null,
          icon: Icons.chevron_right,
        ),
      ),
    );
  }
}

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
  UpdateChecker? _updateChecker;
  var _checkingUpdate = false;

  /// 延迟创建更新检查器，确保使用加载完成的版本号。
  UpdateChecker get _checker => _updateChecker ??=
      UpdateChecker(currentVersion: _appVersion == '…' ? '0.0.0' : _appVersion);

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
        _updateChecker = null;
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
      final result = await _checker.check();
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
      builder: (_) => _UpdateDialog(
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
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final installer = UpdateInstaller();
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
    final dm = context.watch<DomainManager>();
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final cells = <Widget>[
      ListTile(
        leading: const Icon(Icons.brightness_6_outlined),
        title: const Text('外观模式'),
        subtitle: Text(_themeModeLabel(themeMode)),
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
        subtitle: Text(dm.isAutoMode ? '自动' : _hostOf(dm.currentUrl)),
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
                title: Text(_themeModeLabel(mode)),
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
      builder: (sheetContext) => _LinePickerSheet(
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
              content: Text(isAuto ? '已切换到自动线路' : '已切换到 ${_hostOf(url)}'),
            ),
          );
        },
      ),
    );
  }
}

/// 线路选择底部弹窗：自动 + 各域名单选行。
class _LinePickerSheet extends StatelessWidget {
  const _LinePickerSheet({
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
                title: Text(_hostOf(url)),
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

class _CellScaffold extends StatelessWidget {
  const _CellScaffold({required this.title, required this.cells});

  final String title;
  final List<_ProfileCell> cells;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView.separated(
      itemCount: cells.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => cells[i],
    ),
  );
}

class _ProfileCell extends StatelessWidget {
  const _ProfileCell({
    required this.title,
    required this.icon,
    this.subtitle,
    this.route,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? route;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: route == null ? null : () => context.push(route!),
  );
}

void _noopFilter(Map<String, String> _) {}

/// 外观模式的展示文案。
String _themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => '跟随系统',
  ThemeMode.light => '浅色模式',
  ThemeMode.dark => '深色模式',
};

/// 去掉 URL 的协议前缀，仅显示 host。
String _hostOf(String url) => url.replaceFirst(RegExp(r'^https?://'), '');

/// 更新弹窗：展示新版本号与更新日志，支持下载安装。
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.result, required this.install});

  final UpdateCheckResult result;
  final Future<void> Function(
    UpdateCheckResult result,
    void Function(int received, int total) onProgress,
  ) install;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
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
