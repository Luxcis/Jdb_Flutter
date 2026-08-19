import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/login_guide_card.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/recent_viewed_service.dart';
import 'package:provider/provider.dart';

/// 展示当前用户近期浏览影片的页面。
///
/// 三列 `MovieCard` 宫格，自动分页加载；AppBar 右侧删除按钮可清空全部记录。
/// 可通过 [dataSource] 注入数据源以复用页面或替换默认 API 实现。
class ProfileRecentViewedPage extends StatefulWidget {
  /// 创建使用可选 [dataSource] 的近期浏览页面。
  const ProfileRecentViewedPage({super.key, this.dataSource});

  /// 可选的近期浏览数据源；未提供时使用默认 API 数据源。
  final RecentViewedDataSource? dataSource;

  @override
  State<ProfileRecentViewedPage> createState() =>
      _ProfileRecentViewedPageState();
}

class _ProfileRecentViewedPageState extends State<ProfileRecentViewedPage> {
  late final RecentViewedDataSource _dataSource;
  late final PaginationController<MovieSummary> _controller;
  var _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableRecentViewedDataSource()
            : RecentViewedService(api));
    // 首次加载由 didChangeDependencies 触发（登录态就绪后），
    // 避免与 initState 的 fetch 叠加导致重复请求。
    _controller = PaginationController(fetch: _fetchPage);
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) =>
      _dataSource.getRecentViewed(page: page);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLogged = context.watch<AuthProvider>().isLogged;
    if (isLogged && !_wasLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.read<AuthProvider>().isLogged) return;
        _controller.reloadWith(_fetchPage);
      });
    }
    _wasLoggedIn = isLogged;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmAndClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空近期浏览？'),
        content: const Text('将删除全部浏览记录，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _dataSource.clearRecentViewed();
      if (!mounted) return;
      _controller.reloadWith(_fetchPage);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空近期浏览')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('清空失败，请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogged = context.watch<AuthProvider>().isLogged;
    return Scaffold(
      appBar: AppBar(
        title: const Text('近期浏览'),
        actions: [
          IconButton(
            tooltip: '清空近期浏览',
            onPressed: _confirmAndClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: isLogged
          ? MovieGridView(controller: _controller)
          : const LoginGuideCard(
              message: '登录后查看近期浏览',
              loginPath: '/profile/recent',
            ),
    );
  }
}
