import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:jade/features/search/services/search_movie_service.dart';
import 'package:jade/features/search/widgets/search_movie_filter_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({
    super.key,
    required this.query,
    this.historyStore,
    this.movieDataSource,
  });

  final String query;
  final SearchHistoryStore? historyStore;
  final SearchMovieDataSource? movieDataSource;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>
    with TickerProviderStateMixin {
  late final TextEditingController _controller;
  late final TabController _tab;
  SearchHistoryStore? _historyStore;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _tab = TabController(length: 7, vsync: this);
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
                _ActorSearchTab(query: widget.query),
                _EntitySearchTab(
                  query: widget.query,
                  type: 'series',
                  collectionKey: 'series',
                  titleKey: 'name',
                  countKey: 'movie_count',
                  countSuffix: '部影片',
                ),
                _EntitySearchTab(
                  query: widget.query,
                  type: 'maker',
                  collectionKey: 'makers',
                  titleKey: 'name',
                  countKey: 'movie_count',
                  countSuffix: '部影片',
                ),
                _EntitySearchTab(
                  query: widget.query,
                  type: 'director',
                  collectionKey: 'directors',
                  titleKey: 'name',
                  countKey: 'movie_count',
                  countSuffix: '部影片',
                ),
                _EntitySearchTab(
                  query: widget.query,
                  type: 'list',
                  collectionKey: 'lists',
                  titleKey: 'name',
                  countKey: 'movie_count',
                  countSuffix: '部影片',
                ),
                _CodeSearchTab(query: widget.query),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntitySearchTab extends StatefulWidget {
  const _EntitySearchTab({
    required this.query,
    required this.type,
    required this.collectionKey,
    required this.titleKey,
    required this.countKey,
    required this.countSuffix,
  });

  final String query;
  final String type;
  final String collectionKey;
  final String titleKey;
  final String countKey;
  final String countSuffix;

  @override
  State<_EntitySearchTab> createState() => _EntitySearchTabState();
}

class _EntitySearchTabState extends State<_EntitySearchTab> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final resp = await api.get(
      Endpoints.searchV2,
      queryParameters: {'q': widget.query, 'type': widget.type},
    );
    final data = resp.data as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _items = List<Map<String, dynamic>>.from(
        data[widget.collectionKey] ?? const [],
      );
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, index) {
        final item = _items[index];
        final count = item[widget.countKey] ?? 0;
        return ListTile(
          title: Text('${item[widget.titleKey] ?? item['number'] ?? '-'}'),
          subtitle: Text('$count${widget.countSuffix}'),
          trailing: const Icon(Icons.chevron_right),
        );
      },
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
  const _ActorSearchTab({required this.query});

  final String query;

  @override
  State<_ActorSearchTab> createState() => _ActorSearchTabState();
}

class _ActorSearchTabState extends State<_ActorSearchTab> {
  late final _controller = PaginationController<ActorSummary>(
    fetch: (page) async {
      final api = ApiClient.instanceOrNull;
      if (api == null) {
        return const PagedResult(
          items: [],
          currentPage: 1,
          totalPages: 1,
          total: 0,
        );
      }
      final resp = await api.get(
        Endpoints.searchV2,
        queryParameters: {'q': widget.query, 'type': 'actor', 'page': page},
      );
      final data = resp.data as Map<String, dynamic>;
      return PagedResult(
        items:
            (data['actors'] as List?)
                ?.whereType<Map>()
                .map((json) => Map<String, dynamic>.from(json))
                .map(
                  (json) =>
                      ActorSummary.fromJson(normalizeActorSummaryJson(json)),
                )
                .toList() ??
            [],
        currentPage: apiInt(data['current_page'], 1),
        totalPages: apiInt(data['total_pages'], 1),
        total: apiInt(data['total'], 0),
      );
    },
  );

  @override
  void initState() {
    super.initState();
    _controller.fetchMore();
  }

  @override
  Widget build(BuildContext context) => ActorGridView(controller: _controller);
}

class _CodeSearchTab extends StatefulWidget {
  const _CodeSearchTab({required this.query});

  final String query;

  @override
  State<_CodeSearchTab> createState() => _CodeSearchTabState();
}

class _CodeSearchTabState extends State<_CodeSearchTab> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final resp = await api.get(
      Endpoints.searchV2,
      queryParameters: {'q': widget.query, 'type': 'code'},
    );
    final data = resp.data as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _items = List<Map<String, dynamic>>.from(data['codes'] ?? const []);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, index) => ListTile(
        title: Text('${_items[index]['number']}'),
        subtitle: Text('${_items[index]['movie_count'] ?? 0}部影片'),
      ),
    );
  }
}
