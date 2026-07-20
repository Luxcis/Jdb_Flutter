import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/paged_result.dart';
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
    _saveQuery(q);
    setState(() {
      _query = q;
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
          if (history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('历史搜索',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(onPressed: onClear, child: const Text('清空')),
                ],
              ),
            ),
          ...history.map(
            (h) => ListTile(title: Text(h), onTap: () => onTap(h)),
          ),
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
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TabBar(controller: _tab, tabs: const [
            Tab(text: '影片'),
            Tab(text: '演员'),
            Tab(text: '番号'),
          ]),
          Expanded(
            child: TabBarView(controller: _tab, children: [
              _MovieSearchTab(query: widget.query),
              _ActorSearchTab(query: widget.query),
              _CodeSearchTab(query: widget.query),
            ]),
          ),
        ],
      );
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
      final resp = await api.get('/api/v2/search', queryParameters: {
        'q': widget.query,
        'page': page,
      });
      final m = resp.data as Map<String, dynamic>;
      return PagedResult(
        items: (m['movies'] as List?)
                ?.map((j) => MovieSummary.fromJson(j))
                .toList() ??
            [],
        currentPage: m['current_page'] ?? 1,
        totalPages: m['total_pages'] ?? 1,
        total: m['total'] ?? 0,
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
      final resp = await api.get('/api/v2/search', queryParameters: {
        'q': widget.query,
        'type': 'actor',
        'page': page,
      });
      final m = resp.data as Map<String, dynamic>;
      return PagedResult(
        items: (m['actors'] as List?)
                ?.map((j) => ActorSummary.fromJson(j))
                .toList() ??
            [],
        currentPage: m['current_page'] ?? 1,
        totalPages: m['total_pages'] ?? 1,
        total: m['total'] ?? 0,
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
    final resp = await api.get('/api/v2/search', queryParameters: {
      'q': widget.query,
      'type': 'code',
    });
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
