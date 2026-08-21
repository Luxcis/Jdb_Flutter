import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/profile/services/user_lists_service.dart';

/// 「我的-我的清单」页：分页清单列表，支持排序切换与左滑编辑/删除。
class MyListsPage extends StatefulWidget {
  const MyListsPage({super.key, this.dataSource});

  final UserListsDataSource? dataSource;

  @override
  State<MyListsPage> createState() => _MyListsPageState();
}

class _MyListsPageState extends State<MyListsPage> {
  static const _sortByUpdatedAt = 'updated_at';
  static const _sortByCreatedAt = 'created_at';

  late final UserListsDataSource _dataSource;
  late final PaginationController<ListModel> _controller;
  var _sortBy = _sortByUpdatedAt;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableUserListsDataSource()
            : UserListsService(api));
    _controller = PaginationController<ListModel>(fetch: _fetchPage)
      ..fetchMore();
  }

  Future<PagedResult<ListModel>> _fetchPage(int page) =>
      _dataSource.getMyLists(sortBy: _sortBy, page: page);

  void _toggleSort() {
    setState(() {
      _sortBy = _sortBy == _sortByUpdatedAt
          ? _sortByCreatedAt
          : _sortByUpdatedAt;
    });
    _controller.reloadWith(_fetchPage);
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

  Future<void> _renameList(ListModel list) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameListDialog(initialName: list.name),
    );
    if (newName == null || newName.isEmpty || newName == list.name) return;
    setState(() => _busy = true);
    try {
      try {
        await _dataSource.renameList(id: list.id, name: newName);
      } catch (error, stackTrace) {
        developer.log(
          '重命名清单失败',
          name: 'my-lists',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted) return;
        _showMessage('重命名失败');
        return;
      }
      if (!mounted) return;
      // 服务器为准：重载第一页，同时清掉分页状态与残留错误。
      // reloadWith 保留清空语义：GET 失败时旧列表不残留（错误态兜底），
      // 重命名已成功，不能再误报「重命名失败」。
      await _controller.reloadWith(_fetchPage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteList(ListModel list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除清单？'),
        content: Text('确定删除清单「${list.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      try {
        await _dataSource.deleteList(list.id);
      } catch (error, stackTrace) {
        developer.log(
          '删除清单失败',
          name: 'my-lists',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted) return;
        _showMessage('删除失败');
        return;
      }
      if (!mounted) return;
      // 服务器为准：重载第一页，同时清掉分页状态与残留错误。
      // reloadWith 保留清空语义：GET 失败时旧列表不残留（错误态兜底），
      // 删除已成功，不能再误报「删除失败」。
      await _controller.reloadWith(_fetchPage);
      if (!mounted) return;
      _showMessage('清单已删除');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortLabel = _sortBy == _sortByUpdatedAt ? '更新时间' : '创建时间';
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('我的清单'),
            actions: [
              IconButton(
                key: const Key('my-lists-sort-button'),
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
                    onPressed: (_) => unawaited(_renameList(list)),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    icon: Icons.edit_outlined,
                    label: '编辑',
                  ),
                  SlidableAction(
                    onPressed: (_) => unawaited(_deleteList(list)),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    icon: Icons.delete_outline,
                    label: '删除',
                  ),
                ],
              ),
              child: ListSummaryTile(list: list),
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

/// 编辑清单名称弹窗：自管理 TextEditingController，避免对话框退出动画期间
/// 控制器被提前释放。
class _RenameListDialog extends StatefulWidget {
  const _RenameListDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameListDialog> createState() => _RenameListDialogState();
}

class _RenameListDialogState extends State<_RenameListDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('编辑清单'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: '清单名称'),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(onPressed: _submit, child: const Text('保存')),
    ],
  );
}
