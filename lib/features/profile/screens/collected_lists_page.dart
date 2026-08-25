import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/collections_service.dart';

/// 收藏的清单页：排序切换 + 左滑取消收藏。
class CollectedListsPage extends StatefulWidget {
  const CollectedListsPage({super.key, this.dataSource});

  final FavoritesDataSource? dataSource;

  @override
  State<CollectedListsPage> createState() => _CollectedListsPageState();
}

class _CollectedListsPageState extends State<CollectedListsPage> {
  static const _sortByRecently = 'recently';
  static const _sortByRelease = 'release';

  late final FavoritesDataSource _dataSource;
  late final PaginationController<ListModel> _controller;
  var _sortBy = _sortByRecently;
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
    _controller = PaginationController<ListModel>(
      fetch: (page) =>
          _dataSource.getCollectedLists(sortBy: _sortBy, page: page),
    )..fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleSort() {
    setState(() {
      _sortBy = _sortBy == _sortByRecently ? _sortByRelease : _sortByRecently;
    });
    _controller.reloadWith(
      (page) => _dataSource.getCollectedLists(sortBy: _sortBy, page: page),
    );
  }

  Future<void> _uncollectList(ListModel list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取消收藏清单？'),
        content: Text('确定取消收藏「${list.name}」吗？'),
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
        await _dataSource.uncollectList(list.id);
      } catch (error, stackTrace) {
        developer.log(
          '取消收藏清单失败',
          name: 'collected-lists',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted) return;
        _showMessage('取消收藏失败');
        return;
      }
      if (!mounted) return;
      // 服务器为准：重载第一页，同时清掉分页状态与残留错误。
      await _controller.reloadWith(
        (page) => _dataSource.getCollectedLists(sortBy: _sortBy, page: page),
      );
      if (!mounted) return;
      _showMessage('已取消收藏');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortLabel = _sortBy == _sortByRecently ? '更新时间' : '创建时间';
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('收藏的清单'),
            actions: [
              IconButton(
                key: const Key('collected-lists-sort-button'),
                tooltip: '排序：$sortLabel',
                onPressed: _toggleSort,
                icon: const Icon(Icons.sort),
              ),
            ],
          ),
          body: PaginatedListView<ListModel>(
            controller: _controller,
            emptyMessage: '暂无清单',
            itemBuilder: (context, list) => Slidable(
              key: ValueKey('slidable-${list.id}'),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => unawaited(_uncollectList(list)),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    icon: Icons.delete_outline,
                    label: '取消收藏',
                  ),
                ],
              ),
              child: ListSummaryTile(list: list),
            ),
          ),
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
