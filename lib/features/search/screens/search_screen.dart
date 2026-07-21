import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/storage/storage_keys.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<String> _history = [];
  bool _showingResults = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.searchHistory);
    if (raw != null) {
      setState(() => _history = List<String>.from(jsonDecode(raw)));
    }
  }

  void _saveQuery(String q) async {
    _history.remove(q);
    _history.insert(0, q);
    if (_history.length > 20) _history = _history.sublist(0, 20);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.searchHistory, jsonEncode(_history));
    setState(() {});
  }

  void _search(String q) {
    final keyword = q.trim();
    if (keyword.isEmpty) return;
    _saveQuery(keyword);
    setState(() {
      _query = keyword;
      _showingResults = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: !_showingResults,
          decoration: const InputDecoration(
            hintText: '搜索...',
            border: InputBorder.none,
          ),
          onSubmitted: (v) => _search(v),
        ),
      ),
      body: _showingResults
          ? _ResultView(query: _query)
          : _HistoryView(
              history: _history,
              onTap: _search,
              onClear: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(StorageKeys.searchHistory);
                setState(() => _history = []);
              },
            ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  final List<String> history;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;
  const _HistoryView({
    required this.history,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Text('近期热搜', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const ['SSIS', 'FC2', '无码', '新人', '字幕']
              .map((word) => ActionChip(label: Text(word), onPressed: null))
              .toList(),
        ),
      ),
      if (history.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('历史搜索', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: onClear, child: const Text('清空')),
            ],
          ),
        ),
      ...history.map((h) => ListTile(title: Text(h), onTap: () => onTap(h))),
    ],
  );
}

class _ResultView extends StatefulWidget {
  final String query;
  const _ResultView({required this.query});
  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView>
    with TickerProviderStateMixin {
  late final TabController _tab = TabController(length: 7, vsync: this);

  @override
  Widget build(BuildContext context) => Column(
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
            _MovieSearchTab(query: widget.query),
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
  );
}

class _EntitySearchTab extends StatefulWidget {
  final String query;
  final String type;
  final String collectionKey;
  final String titleKey;
  final String countKey;
  final String countSuffix;

  const _EntitySearchTab({
    required this.query,
    required this.type,
    required this.collectionKey,
    required this.titleKey,
    required this.countKey,
    required this.countSuffix,
  });

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
      setState(() => _isLoading = false);
      return;
    }
    final resp = await api.get(
      Endpoints.searchV2,
      queryParameters: {'q': widget.query, 'type': widget.type},
    );
    final m = resp.data as Map<String, dynamic>;
    setState(() {
      _items = List<Map<String, dynamic>>.from(m[widget.collectionKey] ?? []);
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
      itemBuilder: (_, i) {
        final item = _items[i];
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
  final String query;
  const _MovieSearchTab({required this.query});
  @override
  State<_MovieSearchTab> createState() => _MovieSearchTabState();
}

class _MovieSearchTabState extends State<_MovieSearchTab> {
  late final _ctrl = PaginationController<MovieSummary>(
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
        queryParameters: {'q': widget.query, 'page': page},
      );
      final m = resp.data as Map<String, dynamic>;
      return PagedResult(
        items:
            (m['movies'] as List?)
                ?.whereType<Map>()
                .map((j) => Map<String, dynamic>.from(j))
                .map((j) => MovieSummary.fromJson(normalizeMovieSummaryJson(j)))
                .toList() ??
            [],
        currentPage: apiInt(m['current_page'], 1),
        totalPages: apiInt(m['total_pages'], 1),
        total: apiInt(m['total'], 0),
      );
    },
  );

  @override
  void initState() {
    super.initState();
    _ctrl.fetchMore();
  }

  @override
  Widget build(BuildContext context) => MovieGridView(controller: _ctrl);
}

class _ActorSearchTab extends StatefulWidget {
  final String query;
  const _ActorSearchTab({required this.query});
  @override
  State<_ActorSearchTab> createState() => _ActorSearchTabState();
}

class _ActorSearchTabState extends State<_ActorSearchTab> {
  late final _ctrl = PaginationController<ActorSummary>(
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
      final m = resp.data as Map<String, dynamic>;
      return PagedResult(
        items:
            (m['actors'] as List?)
                ?.whereType<Map>()
                .map((j) => Map<String, dynamic>.from(j))
                .map((j) => ActorSummary.fromJson(normalizeActorSummaryJson(j)))
                .toList() ??
            [],
        currentPage: apiInt(m['current_page'], 1),
        totalPages: apiInt(m['total_pages'], 1),
        total: apiInt(m['total'], 0),
      );
    },
  );

  @override
  void initState() {
    super.initState();
    _ctrl.fetchMore();
  }

  @override
  Widget build(BuildContext context) => ActorGridView(controller: _ctrl);
}

class _CodeSearchTab extends StatefulWidget {
  final String query;
  const _CodeSearchTab({required this.query});
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

  void _load() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      setState(() => _isLoading = false);
      return;
    }
    final resp = await api.get(
      Endpoints.searchV2,
      queryParameters: {'q': widget.query, 'type': 'code'},
    );
    final m = resp.data as Map<String, dynamic>;
    setState(() {
      _items = List<Map<String, dynamic>>.from(m['codes'] ?? []);
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
      itemBuilder: (_, i) => ListTile(
        title: Text('${_items[i]['number']}'),
        subtitle: Text('${_items[i]['movie_count'] ?? 0}部影片'),
      ),
    );
  }
}
