import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';

/// 影片详情「存入清单」底部弹窗。
class MovieSaveToListSheet extends StatefulWidget {
  const MovieSaveToListSheet({
    super.key,
    required this.service,
    required this.movieId,
    required this.initialLists,
  });

  final MovieDetailService service;
  final String movieId;
  final List<ListModel> initialLists;

  @override
  State<MovieSaveToListSheet> createState() => _MovieSaveToListSheetState();
}

class _MovieSaveToListSheetState extends State<MovieSaveToListSheet> {
  static const int _pageSize = 48;

  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _pendingListIds = {};
  List<ListModel> _lists = [];
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _creating = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreIfNeeded);
    _lists = widget.initialLists;
    _hasMore = widget.initialLists.length >= _pageSize;
    _loading = false;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    if (mounted) {
      setState(() {
        _page = 1;
        _loading = true;
        _error = null;
        _hasMore = false;
      });
    }
    try {
      final lists = await widget.service.getSimpleLists(
        widget.movieId,
        page: 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _hasMore = lists.length >= _pageSize;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _loadMoreIfNeeded() {
    if (!_hasMore || _loading || _loadingMore) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.extentAfter > 240) return;
    unawaited(_loadNextPage());
  }

  Future<void> _loadNextPage() async {
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    try {
      final lists = await widget.service.getSimpleLists(
        widget.movieId,
        page: nextPage,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _lists = [..._lists, ...lists];
        _hasMore = lists.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _showMessage('清单加载失败');
    }
  }

  Future<void> _toggleList(ListModel list) async {
    if (_pendingListIds.contains(list.id)) return;
    final index = _lists.indexWhere((item) => item.id == list.id);
    if (index < 0) return;
    final nextHasMovie = !list.hasMovie;
    final nextCount = (list.movieCount + (nextHasMovie ? 1 : -1)).clamp(
      0,
      1 << 31,
    );
    setState(() {
      _pendingListIds.add(list.id);
      _lists[index] = list.copyWith(
        hasMovie: nextHasMovie,
        movieCount: nextCount,
      );
    });
    try {
      await widget.service.toggleMovieInList(
        listId: list.id,
        movieId: widget.movieId,
        action: nextHasMovie ? 'add' : 'remove',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _lists[index] = list);
      _showMessage(nextHasMovie ? '添加失败' : '移除失败');
    } finally {
      if (mounted) {
        setState(() => _pendingListIds.remove(list.id));
      }
    }
  }

  Future<void> _createList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      await widget.service.createListWithMovie(
        name: name,
        movieId: widget.movieId,
      );
      if (!mounted) return;
      _nameController.clear();
      await _loadFirstPage();
    } catch (error) {
      if (!mounted) return;
      _showMessage('创建清单失败');
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '存入清单',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('movie-list-name-field'),
                      controller: _nameController,
                      enabled: !_creating,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => unawaited(_createList()),
                      decoration: const InputDecoration(
                        labelText: '新清单名称',
                        isDense: true,
                      ),
                    ),
                  ),
                  FilledButton(
                    key: const Key('movie-list-create-button'),
                    onPressed: _creating
                        ? null
                        : () => unawaited(_createList()),
                    child: Text(_creating ? '创建中' : '创建'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorRetryWidget(message: '清单加载失败', onRetry: _loadFirstPage);
    }
    if (_lists.isEmpty) {
      return const Center(child: Text('暂无清单'));
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _lists.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _lists.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = _lists[index];
        final pending = _pendingListIds.contains(list.id);
        return CheckboxListTile(
          value: list.hasMovie,
          onChanged: pending ? null : (_) => unawaited(_toggleList(list)),
          title: Text(list.name),
          subtitle: Text('${list.movieCount} 部影片，被查看 ${list.viewedCount} 次'),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: pending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        );
      },
    );
  }
}
