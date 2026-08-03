import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/magnet_list_tile.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/features/search/models/magnet_search_sort.dart';
import 'package:jade/features/search/services/magnet_search_service.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MagnetSearchResultsPage extends StatefulWidget {
  const MagnetSearchResultsPage({
    super.key,
    required this.query,
    required this.fromRecent,
    this.historyStore,
    this.dataSource,
  });

  final String query;
  final bool fromRecent;
  final SearchHistoryStore? historyStore;
  final MagnetSearchDataSource? dataSource;

  @override
  State<MagnetSearchResultsPage> createState() =>
      _MagnetSearchResultsPageState();
}

class _MagnetSearchResultsPageState extends State<MagnetSearchResultsPage> {
  late final TextEditingController _textController;
  late final MagnetSearchDataSource _dataSource;
  late final PaginationController<Magnet> _controller;
  SearchHistoryStore? _historyStore;
  var _sort = MagnetSearchSort.relevance;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.query);
    _historyStore = widget.historyStore;
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const _UnavailableMagnetSearchDataSource()
            : MagnetSearchService(api));
    _controller = PaginationController<Magnet>(fetch: _fetchPage)..fetchMore();
  }

  Future<PagedResult<Magnet>> _fetchPage(int page) {
    return _dataSource.getMagnets(
      query: widget.query,
      sort: _sort,
      fromRecent: widget.fromRecent,
      page: page,
    );
  }

  void _changeSort(MagnetSearchSort value) {
    if (_sort == value) return;
    setState(() => _sort = value);
    unawaited(_controller.reloadWith(_fetchPage));
  }

  Future<SearchHistoryStore> _resolveHistoryStore() async {
    final existing = _historyStore;
    if (existing != null) return existing;
    final store = SearchHistoryStore(
      await SharedPreferences.getInstance(),
      storageKey: StorageKeys.magnetSearchHistory,
    );
    _historyStore = store;
    return store;
  }

  Future<void> _search(String value) async {
    final keyword = value.trim();
    if (keyword.isEmpty) return;
    final store = await _resolveHistoryStore();
    await store.save(keyword);
    if (!mounted) return;
    context.pushReplacement(
      Uri(
        path: AppRoutes.magnetSearchResults,
        queryParameters: {'q': keyword, 'from_recent': 'false'},
      ).toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _textController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索磁链...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SortSegmented<MagnetSearchSort>(
              key: const Key('magnet-sort-filter'),
              compact: true,
              expanded: true,
              options: [
                for (final sort in MagnetSearchSort.values)
                  (label: sort.label, value: sort),
              ],
              value: _sort,
              onChanged: _changeSort,
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, child) => _buildResults(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_controller.error != null && _controller.items.isEmpty) {
      return ErrorRetryWidget(message: '磁链搜索失败', onRetry: _controller.refresh);
    }
    if (_controller.isLoading && _controller.items.isEmpty) {
      return const Center(
        key: Key('magnet-results-initial-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_controller.items.isEmpty) {
      return const EmptyState(message: '未找到相关磁链');
    }
    final showFooter =
        _controller.isLoading ||
        (_controller.error != null && _controller.items.isNotEmpty);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            _controller.hasMore &&
            _controller.error == null) {
          unawaited(_controller.fetchMore());
        }
        return false;
      },
      child: ListView.separated(
        key: const Key('magnet-results-list'),
        itemCount: _controller.items.length + (showFooter ? 1 : 0),
        separatorBuilder: (context, index) => const MagnetListDivider(),
        itemBuilder: (context, index) {
          if (index < _controller.items.length) {
            return MagnetListTile(magnet: _controller.items[index]);
          }
          if (_controller.isLoading) {
            return const Padding(
              key: Key('magnet-results-loading-more'),
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Center(
            child: TextButton.icon(
              key: const Key('magnet-load-more-retry'),
              onPressed: _controller.fetchMore,
              icon: const Icon(Icons.refresh),
              label: const Text('加载失败，点击重试'),
            ),
          );
        },
      ),
    );
  }
}

class _UnavailableMagnetSearchDataSource implements MagnetSearchDataSource {
  const _UnavailableMagnetSearchDataSource();

  @override
  Future<PagedResult<Magnet>> getMagnets({
    required String query,
    required MagnetSearchSort sort,
    required bool fromRecent,
    int page = 1,
  }) async {
    return PagedResult(
      items: const [],
      currentPage: page,
      totalPages: page,
      total: 0,
    );
  }
}
