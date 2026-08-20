import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/collections_service.dart';
import 'package:go_router/go_router.dart';

/// 收藏的演员页：4 Tab（全部/有码/无码/欧美）+ 编辑批量取关。
class CollectedActorsPage extends StatefulWidget {
  const CollectedActorsPage({super.key, this.dataSource});

  final FavoritesDataSource? dataSource;

  @override
  State<CollectedActorsPage> createState() => _CollectedActorsPageState();
}

class _CollectedActorsPageState extends State<CollectedActorsPage>
    with TickerProviderStateMixin {
  static const _tabs = [
    (label: '全部', type: 'all'),
    (label: '有码', type: '0'),
    (label: '无码', type: '1'),
    (label: '欧美', type: '2'),
  ];

  late final FavoritesDataSource _dataSource;
  late final TabController _tabController;
  late final List<PaginationController<ActorSummary>> _controllers;
  final _loadedTabs = <int>{};
  final _selectedIds = <String>{};
  var _editing = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableFavoritesDataSource()
            : FavoritesService(api));
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _controllers = [
      for (final tab in _tabs)
        PaginationController<ActorSummary>(
          fetch: (page) =>
              _dataSource.getCollectedActors(type: tab.type, page: page),
        ),
    ];
    _loadTab(0);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    for (final controller in _controllers) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadTab(_tabController.index);
  }

  /// 惰性加载：仅首次切换到某个 Tab 时发起请求（测试与性能均按需加载）。
  void _loadTab(int index) {
    if (_loadedTabs.contains(index)) return;
    _loadedTabs.add(index);
    _controllers[index].fetchMore();
  }

  void _toggleEdit() {
    setState(() {
      _editing = !_editing;
      if (!_editing) _selectedIds.clear();
    });
  }

  void _toggleSelect(ActorSummary actor) {
    setState(() {
      if (!_selectedIds.add(actor.id)) _selectedIds.remove(actor.id);
    });
  }

  Future<void> _batchUncollect() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取消收藏演员？'),
        content: Text('确定取消收藏选中的 ${ids.length} 位演员吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      try {
        await _dataSource.batchUncollectActors(ids);
      } catch (error, stackTrace) {
        developer.log(
          '批量取关失败',
          name: 'collected-actors',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted) return;
        _showMessage('批量取关失败');
        return;
      }
      if (!mounted) return;
      // 服务器为准：批量取关后所有已加载 Tab 统一重载，避免其他 Tab
      // 残留已取消收藏的演员（仍可被再次选中）。
      for (final index in _loadedTabs.toList()) {
        await _controllers[index].reloadWith(
          (page) =>
              _dataSource.getCollectedActors(type: _tabs[index].type, page: page),
        );
      }
      if (!mounted) return;
      setState(() {
        _editing = false;
        _selectedIds.clear();
      });
      _showMessage('已取消收藏 ${ids.length} 位演员');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('收藏的演员'),
            actions: [
              if (!_editing)
                IconButton(
                  key: const Key('collected-actors-edit-button'),
                  tooltip: '编辑',
                  onPressed: _toggleEdit,
                  icon: const Icon(Icons.edit_outlined),
                )
              else
                TextButton(
                  key: const Key('collected-actors-done-button'),
                  onPressed: _toggleEdit,
                  child: const Text('完成'),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: _tabs
                  .map((tab) => Tab(text: tab.label))
                  .toList(growable: false),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              for (var i = 0; i < _tabs.length; i++)
                ActorGridView(
                  controller: _controllers[i],
                  onActorTap: _editing
                      ? null
                      : (actor) => context.push('/actor/${actor.id}'),
                  selectionMode: _editing,
                  selectedIds: _selectedIds,
                  onToggleSelect: _editing ? _toggleSelect : null,
                ),
            ],
          ),
          bottomNavigationBar: _editing
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      key: const Key('collected-actors-batch-button'),
                      onPressed: _selectedIds.isEmpty ? null : _batchUncollect,
                      icon: const Icon(Icons.delete_outline),
                      label: Text('取消收藏(${_selectedIds.length})'),
                    ),
                  ),
                )
              : null,
        ),
        if (_busy)
          const Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Color(0x73000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}
