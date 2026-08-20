import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/collections_service.dart';

/// 收藏的实体（片商/系列/导演/番号）分页页：左滑取消收藏，点击进影片列表。
class CollectedEntitiesPage extends StatefulWidget {
  const CollectedEntitiesPage({
    super.key,
    required this.category,
    required this.title,
    this.dataSource,
  });

  final String category; // m / s / d / c
  final String title;
  final FavoritesDataSource? dataSource;

  @override
  State<CollectedEntitiesPage> createState() => _CollectedEntitiesPageState();
}

class _CollectedEntitiesPageState extends State<CollectedEntitiesPage> {
  late final FavoritesDataSource _dataSource;
  late final PaginationController<dynamic> _controller;
  var _busy = false;

  Future<PagedResult<dynamic>> _fetchPage(int page) {
    final source = _dataSource;
    return switch (widget.category) {
      'm' => source.getCollectedMakers(page: page),
      's' => source.getCollectedSeries(page: page),
      'd' => source.getCollectedDirectors(page: page),
      'c' => source.getCollectedCodes(page: page),
      _ => Future.value(
        const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableFavoritesDataSource()
            : FavoritesService(api));
    _controller = PaginationController<dynamic>(fetch: _fetchPage)..fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _entityLabel() => switch (widget.category) {
    'm' => '片商',
    's' => '系列',
    'd' => '导演',
    'c' => '番号',
    _ => '内容',
  };

  String _idOf(dynamic item) => switch (widget.category) {
    'm' => (item as Maker).id,
    's' => (item as Series).id,
    'd' => (item as Director).id,
    'c' => (item as Code).id,
    _ => '',
  };

  String _nameOf(dynamic item) => switch (widget.category) {
    'm' => (item as Maker).name,
    's' => (item as Series).name,
    'd' => (item as Director).name,
    'c' => (item as Code).number,
    _ => '',
  };

  int _countOf(dynamic item) => switch (widget.category) {
    'm' => (item as Maker).movieCount,
    's' => (item as Series).movieCount,
    'd' => (item as Director).movieCount,
    'c' => (item as Code).movieCount,
    _ => 0,
  };

  Future<void> _uncollectById(String id) => switch (widget.category) {
    'm' => _dataSource.uncollectMaker(id),
    's' => _dataSource.uncollectSeries(id),
    'd' => _dataSource.uncollectDirector(id),
    'c' => _dataSource.uncollectCode(id),
    _ => Future.value(),
  };

  /// 与搜索页一致跳 common-list（category: m/s/d/c, title: '片商 - X' 等）。
  void _openList(dynamic item) {
    final type = switch (widget.category) {
      'm' => (item as Maker).type,
      's' => (item as Series).type,
      'd' => (item as Director).type,
      'c' => (item as Code).type,
      _ => 0,
    };
    context.push(
      Uri(
        path: AppRoutes.commonList,
        queryParameters: {
          'title': '${_entityLabel()} - ${_nameOf(item)}',
          'type': '$type',
          'category': widget.category,
          'id': _idOf(item),
        },
      ).toString(),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _uncollect(dynamic item) async {
    final id = _idOf(item);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '取消收藏${widget.category == 'c' ? '番号' : '${_entityLabel()}？'}',
        ),
        content: Text('确定取消收藏「${_nameOf(item)}」吗？'),
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
        await _uncollectById(id);
      } catch (error, stackTrace) {
        developer.log(
          '取消收藏失败',
          name: 'collected-entities',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted) return;
        _showMessage('取消收藏失败');
        return;
      }
      if (!mounted) return;
      // 服务器为准：重载第一页，同时清掉分页状态与残留错误。
      await _controller.reloadWith(_fetchPage);
      if (!mounted) return;
      _showMessage('已取消收藏');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: PaginatedListView<dynamic>(
            controller: _controller,
            emptyMessage: '暂无${_entityLabel()}',
            itemBuilder: (context, item) => Slidable(
              key: ValueKey('slidable-${_idOf(item)}'),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => unawaited(_uncollect(item)),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    icon: Icons.delete_outline,
                    label: '取消收藏',
                  ),
                ],
              ),
              child: EntityListTile(
                name: _nameOf(item),
                count: _countOf(item),
                onTap: () => _openList(item),
              ),
            ),
          ),
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x73000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

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
              child: ListSummaryTile(
                list: list,
                onTap: () => context.push(
                  Uri(
                    path: AppRoutes.commonList,
                    queryParameters: {
                      'title': '清单 - ${list.name}',
                      'type': '0',
                      'category': 'l',
                      'id': list.id,
                    },
                  ).toString(),
                ),
              ),
            ),
          ),
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x73000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
