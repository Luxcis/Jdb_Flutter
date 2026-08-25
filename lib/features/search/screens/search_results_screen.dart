import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/features/search/services/search_entity_service.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:jade/features/search/services/search_movie_service.dart';
import 'package:jade/features/search/widgets/search_result_tabs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({
    super.key,
    required this.query,
    this.historyStore,
    this.movieDataSource,
    this.entityDataSource,
  });

  final String query;
  final SearchHistoryStore? historyStore;
  final SearchMovieDataSource? movieDataSource;
  final SearchEntityDataSource? entityDataSource;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>
    with TickerProviderStateMixin {
  late final TextEditingController _controller;
  late final TabController _tab;
  late final SearchEntityDataSource _entityDataSource;
  SearchHistoryStore? _historyStore;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _tab = TabController(length: 7, vsync: this);
    _entityDataSource =
        widget.entityDataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => SearchEntityService(api),
          null => const UnavailableSearchEntityDataSource(),
        };
    _historyStore = widget.historyStore;
  }

  Future<SearchHistoryStore> _resolveHistoryStore() async {
    final existing = _historyStore;
    if (existing != null) return existing;
    final provided = context.read<SearchHistoryStore?>();
    if (provided != null) return _historyStore = provided;
    final prefs = await SharedPreferences.getInstance();
    return _historyStore ??= SearchHistoryStore(prefs);
  }

  Future<void> _search(String value) async {
    final keyword = value.trim();
    if (keyword.isEmpty) return;
    final store = await _resolveHistoryStore();
    await store.save(keyword);
    if (!mounted) return;
    context.replace(
      Uri(
        path: AppRoutes.searchResults,
        queryParameters: {'q': keyword},
      ).toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movieDataSource =
        widget.movieDataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => SearchMovieService(api),
          null => const UnavailableSearchMovieDataSource(),
        };
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: '影片'),
              Tab(text: '演员'),
              Tab(text: '系列'),
              Tab(text: '片商'),
              Tab(text: '导演'),
              Tab(text: '清单'),
              Tab(text: '番号'),
            ],
            isScrollable: true,
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                MovieSearchTab(
                  query: widget.query,
                  dataSource: movieDataSource,
                ),
                ActorSearchTab(
                  query: widget.query,
                  dataSource: _entityDataSource,
                ),
                PaginatedEntitySearchTab<Series>(
                  fetchPage: (page) => _entityDataSource.getSeries(
                    query: widget.query,
                    page: page,
                  ),
                  idOf: (item) => item.id,
                  emptyMessage: '暂无系列',
                  itemBuilder: (context, item) => EntityListTile(
                    name: item.name,
                    count: item.movieCount,
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.commonList,
                        queryParameters: {
                          'title': '系列 - ${item.name}',
                          'type': '${item.type}',
                          'category': 's',
                          'id': item.id,
                        },
                      ).toString(),
                    ),
                  ),
                ),
                PaginatedEntitySearchTab<Maker>(
                  fetchPage: (page) => _entityDataSource.getMakers(
                    query: widget.query,
                    page: page,
                  ),
                  idOf: (item) => item.id,
                  emptyMessage: '暂无片商',
                  itemBuilder: (context, item) => EntityListTile(
                    name: item.name,
                    count: item.movieCount,
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.commonList,
                        queryParameters: {
                          'title': '片商 - ${item.name}',
                          'type': '${item.type}',
                          'category': 'm',
                          'id': item.id,
                        },
                      ).toString(),
                    ),
                  ),
                ),
                PaginatedEntitySearchTab<Director>(
                  fetchPage: (page) => _entityDataSource.getDirectors(
                    query: widget.query,
                    page: page,
                  ),
                  idOf: (item) => item.id,
                  emptyMessage: '暂无导演',
                  itemBuilder: (context, item) => EntityListTile(
                    name: item.name,
                    count: item.movieCount,
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.commonList,
                        queryParameters: {
                          'title': '导演 - ${item.name}',
                          'type': '${item.type}',
                          'category': 'd',
                          'id': item.id,
                        },
                      ).toString(),
                    ),
                  ),
                ),
                PaginatedEntitySearchTab<ListModel>(
                  fetchPage: (page) => _entityDataSource.getLists(
                    query: widget.query,
                    page: page,
                  ),
                  idOf: (item) => item.id,
                  emptyMessage: '暂无清单',
                  itemBuilder: (context, item) => ListSummaryTile(
                    list: item,
                    showViewCount: false,
                  ),
                ),
                PaginatedEntitySearchTab<Code>(
                  fetchPage: (page) => _entityDataSource.getCodes(
                    query: widget.query,
                    page: page,
                  ),
                  idOf: (item) => item.id,
                  emptyMessage: '暂无番号',
                  itemBuilder: (context, item) => EntityListTile(
                    name: item.number,
                    count: item.movieCount,
                    onTap: () => context.push(
                      Uri(
                        path: AppRoutes.commonList,
                        queryParameters: {
                          'title': '番号 - ${item.number}',
                          'type': '${item.type}',
                          'category': 'c',
                          'id': item.id,
                        },
                      ).toString(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
