import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/search_entry.dart';
import 'package:jade/features/categories/services/category_service.dart';
import 'package:jade/features/categories/services/category_tab_controller.dart';
import 'package:jade/features/categories/widgets/category_filter_sheet.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:jade/features/following/widgets/following_tags_button.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, this.dataSource});

  final CategoryDataSource? dataSource;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with TickerProviderStateMixin {
  static const tabs = ['有码', '无码', '欧美', 'FC2', '动漫'];

  late final TabController _tabController;
  late final List<CategoryTabController> _controllers;
  late final CategoryDataSource _source;
  var _selectedIndex = 0;
  var _followingBusy = false;
  List<CategoryTabController> _observed = const [];

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _source =
        widget.dataSource ??
        (api != null
            ? CategoryService(api)
            : const UnavailableCategoryDataSource());
    _controllers = [
      for (var type = 0; type < tabs.length; type++)
        CategoryTabController(type: type, source: _source),
    ];
    _tabController = TabController(length: tabs.length, vsync: this)
      ..addListener(_handleTabChanged);
    _ensureControllerObserver();
  }

  void _handleTabChanged() {
    if (_selectedIndex == _tabController.index || !mounted) return;
    setState(() => _selectedIndex = _tabController.index);
    _ensureControllerObserver();
  }

  /// 为当前选中 tab 的 controller 注册一个后帧监听，使 AppBar 的
  /// 关注按钮能随 filter/sort 变化而重建。
  void _ensureControllerObserver() {
    final target = _controllers[_selectedIndex];
    if (_observed.contains(target)) return;
    _observed = [..._observed, target];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_observed.contains(target)) return;
      target.addListener(_onControllerChanged);
    });
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // 通知可能恰逢 build：懒加载 tab 首次 initialize() 会同步调用
    // retryTags() -> _notify()，此时监听刚经 addPostFrameCallback 挂上、
    // 但目标 controller 恰在下一帧 build 期间被初始化，直接 setState 会抛
    // setState() during build。统一延迟到帧末重建，避免该崩溃。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _showFilter() {
    final height = MediaQuery.sizeOf(context).height * 2 / 3;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints.tightFor(height: height),
      builder: (_) =>
          CategoryFilterSheet(controller: _controllers[_selectedIndex]),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    for (final controller in _observed) {
      controller.removeListener(_onControllerChanged);
    }
    _observed = const [];
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleFollowing(
    CategoryTabController controller,
    String value,
  ) async {
    if (_followingBusy) return;
    setState(() => _followingBusy = true);
    try {
      final provider = context.read<FollowingTagsProvider>();
      if (provider.isFollowing(value)) {
        final tag = provider.tags.firstWhere((t) => t.value == value);
        try {
          await provider.unfollow(tag.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已取消关注')),
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('操作失败，请重试')),
          );
        }
      } else {
        final name = _selectedTagNames(controller);
        try {
          await provider.follow(name: name, value: value);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已关注')),
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('操作失败，请重试')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _followingBusy = false);
    }
  }

  String _selectedTagNames(CategoryTabController controller) {
    // 把当前 Tab 名称（有码/无码/欧美/FC2/动漫）放在最前面，如「有码,含字幕」。
    final names = <String>[tabs[controller.type]];
    for (final group in controller.groups) {
      final selected = controller.filter.selectedValues(group.categoryId);
      for (final item in group.tags) {
        if (selected.contains(item.id)) names.add(item.name);
      }
    }
    return names.join(',');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('类别'),
        actions: [
          Builder(builder: (context) {
            final controller = _controllers[_selectedIndex];
            final followed = context.watch<FollowingTagsProvider>();
            final value = controller.filter.toFilterBy(
              controller.type,
              controller.groupOrder,
            );
            return FollowingTagsButton(
              following: followed.isFollowing(value),
              enabled: controller.hasSelectedTags,
              busy: _followingBusy,
              onPressed: () => _toggleFollowing(controller, value),
            );
          }),
          IconButton(
            key: const Key('categories-filter-button'),
            tooltip: '筛选',
            onPressed: _showFilter,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          const SearchIconButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in tabs) Tab(text: tab)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final controller in _controllers)
            _CategoryTab(
              key: PageStorageKey<int>(controller.type),
              controller: controller,
            ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatefulWidget {
  const _CategoryTab({super.key, required this.controller});

  final CategoryTabController controller;

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MovieGridView(
      key: Key('category-tab-grid-${widget.controller.type}'),
      controller: widget.controller.movies,
    );
  }
}
