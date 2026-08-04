import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';
import 'package:jade/features/search/services/search_entity_service.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:jade/features/search/services/search_movie_service.dart';
import 'package:jade/features/search/services/search_page_session.dart';
import 'package:jade/features/search/widgets/search_entity_list_tile.dart';
import 'package:jade/features/search/widgets/search_movie_filter_bar.dart';
import 'package:jade/features/search/widgets/search_paginated_list_view.dart';
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
                _MovieSearchTab(
                  query: widget.query,
                  dataSource: movieDataSource,
                ),
                _ActorSearchTab(
                  query: widget.query,
                  dataSource: _entityDataSource,
                ),
                _PaginatedEntitySearchTab<Series>(
                  fetchPage: (page) => _entityDataSource.getSeries(
                    query: widget.query,
                    page: page,
                  ),
                  idOf: (item) => item.id,
                  emptyMessage: '暂无系列',
                  itemBuilder: (context, item) => SearchEntityListTile(
                    name: item.name,
                    count: item.movieCount,
                    onTap: () => _openCommonList(
                      context,
                      '系列',
                      item.name,
                      item.type,
                      's',
                      item.id,
                    ),
                  ),
                ),
                _PaginatedEntitySearchTab<Maker>(
                  fetchPage: (page) => _entityDataSource.getMakers(
                    query: widget.query,
                    page: page,
                  ),
                  idOf: (item) => item.id,
                  emptyMessage: '暂无片商',
                  itemBuilder: (context, item) => SearchEntityListTile(
                    name: item.name,
                    count: item.movieCount,
                    onTap: () => _openCommonList(
                      context,
                      '片商',
                      item.name,
                      item.type,
                      'm',
                      item.id,
                    ),
                  ),
                ),
                _PaginatedEntitySearchTab<Director>(
                  fetchPage: (page) => _entityDataSource.getDirectors(
                    query: widget.query,
                    page: page,
                  ),
                  idOf: (item) => item.id,
                  emptyMessage: '暂无导演',
                  itemBuilder: (context, item) => SearchEntityListTile(
                    name: item.name,
                    count: item.movieCount,
                    onTap: () => _openCommonList(
                      context,
                      '导演',
                      item.name,
                      item.type,
                      'd',
                      item.id,
                    ),
                  ),
                ),
                _PaginatedEntitySearchTab<ListModel>(
                  fetchPage: (page) => _entityDataSource.getLists(
                    query: widget.query,
                    page: page,
                  ),
                  idOf: (item) => item.id,
                  emptyMessage: '暂无清单',
                  itemBuilder: (context, item) => ListSummaryTile(
                    list: item,
                    showViewCount: false,
                    onTap: () => _openCommonList(
                      context,
                      '清单',
                      item.name,
                      0,
                      'l',
                      item.id,
                    ),
                  ),
                ),
                _PaginatedEntitySearchTab<Code>(
                  fetchPage: (page) => _entityDataSource.getCodes(
                    query: widget.query,
                    page: page,
                  ),
                  idOf: (item) => item.id,
                  emptyMessage: '暂无番号',
                  itemBuilder: (context, item) => SearchEntityListTile(
                    name: item.number,
                    count: item.movieCount,
                    onTap: () => _openCommonList(
                      context,
                      '番号',
                      item.number,
                      item.type,
                      'c',
                      item.id,
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

typedef _EntityItemBuilder<T> = Widget Function(BuildContext context, T item);

class _PaginatedEntitySearchTab<T> extends StatefulWidget {
  const _PaginatedEntitySearchTab({
    required this.fetchPage,
    required this.idOf,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final Future<PagedResult<T>> Function(int page) fetchPage;
  final String Function(T item) idOf;
  final _EntityItemBuilder<T> itemBuilder;
  final String emptyMessage;

  @override
  State<_PaginatedEntitySearchTab<T>> createState() =>
      _PaginatedEntitySearchTabState<T>();
}

class _PaginatedEntitySearchTabState<T>
    extends State<_PaginatedEntitySearchTab<T>>
    with AutomaticKeepAliveClientMixin {
  late final PaginationController<T> _controller;

  @override
  void initState() {
    super.initState();
    final session = SearchPageSession<T>(
      fetchPage: widget.fetchPage,
      idOf: widget.idOf,
    );
    _controller = PaginationController<T>(fetch: session.fetch)..fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SearchPaginatedListView<T>(
      controller: _controller,
      itemBuilder: widget.itemBuilder,
      emptyMessage: widget.emptyMessage,
    );
  }
}

class _MovieSearchTab extends StatefulWidget {
  const _MovieSearchTab({required this.query, required this.dataSource});

  final String query;
  final SearchMovieDataSource dataSource;

  @override
  State<_MovieSearchTab> createState() => _MovieSearchTabState();
}

class _MovieSearchTabState extends State<_MovieSearchTab> {
  late final PaginationController<MovieSummary> _controller;
  SearchMovieFilter _filter = const SearchMovieFilter();

  Future<PagedResult<MovieSummary>> _fetchPage(int page) => widget.dataSource
      .getMovies(query: widget.query, filter: _filter, page: page);

  Future<void> _changeFilter(SearchMovieFilter value) async {
    if (value.type == _filter.type &&
        value.availability == _filter.availability &&
        value.sort == _filter.sort) {
      return;
    }
    setState(() => _filter = value);
    await _controller.reloadWith(_fetchPage);
  }

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<MovieSummary>(fetch: _fetchPage);
    _controller.fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchMovieFilterBar(value: _filter, onChanged: _changeFilter),
        Expanded(child: MovieGridView(controller: _controller)),
      ],
    );
  }
}

class _ActorSearchTab extends StatefulWidget {
  const _ActorSearchTab({required this.query, required this.dataSource});

  final String query;
  final SearchEntityDataSource dataSource;

  @override
  State<_ActorSearchTab> createState() => _ActorSearchTabState();
}

class _ActorSearchTabState extends State<_ActorSearchTab>
    with AutomaticKeepAliveClientMixin {
  late final PaginationController<ActorSummary> _controller;

  @override
  void initState() {
    super.initState();
    final session = SearchPageSession<ActorSummary>(
      fetchPage: (page) =>
          widget.dataSource.getActors(query: widget.query, page: page),
      idOf: (item) => item.id,
    );
    _controller = PaginationController<ActorSummary>(fetch: session.fetch)
      ..fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ActorGridView(
      controller: _controller,
      onActorTap: (actor) => context.push('/actor/${actor.id}'),
    );
  }
}

void _openCommonList(
  BuildContext context,
  String typeLabel,
  String name,
  int type,
  String category,
  String id,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CommonListPage(
        title: '$typeLabel - $name',
        type: type,
        category: category,
        id: id,
      ),
    ),
  );
}
