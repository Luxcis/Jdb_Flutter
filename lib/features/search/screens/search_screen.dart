import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:jade/features/search/widgets/search_keyword_section.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.historyStore, this.recentKeywords});

  final SearchHistoryStore? historyStore;
  final List<String>? recentKeywords;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  SearchHistoryStore? _historyStore;
  List<String> _history = const [];

  @override
  void initState() {
    super.initState();
    final historyStore = widget.historyStore;
    if (historyStore != null) _attachHistoryStore(historyStore);
    _loadHistory();
  }

  void _attachHistoryStore(SearchHistoryStore store) {
    if (identical(_historyStore, store)) return;
    _historyStore?.removeListener(_handleHistoryChanged);
    _historyStore = store;
    store.addListener(_handleHistoryChanged);
  }

  void _handleHistoryChanged() {
    final store = _historyStore;
    if (!mounted || store == null) return;
    setState(() => _history = store.load());
  }

  Future<SearchHistoryStore> _resolveHistoryStore() async {
    final existing = _historyStore;
    if (existing != null) return existing;
    final provided = context.read<SearchHistoryStore?>();
    if (provided != null) {
      _attachHistoryStore(provided);
      return provided;
    }
    final prefs = await SharedPreferences.getInstance();
    final store = SearchHistoryStore(prefs);
    _attachHistoryStore(store);
    return store;
  }

  Future<void> _loadHistory() async {
    final store = await _resolveHistoryStore();
    final history = store.load();
    if (!mounted) return;
    setState(() => _history = history);
  }

  Future<void> _search(String value) async {
    final keyword = value.trim();
    if (keyword.isEmpty) return;
    final store = await _resolveHistoryStore();
    final history = await store.save(keyword);
    if (!mounted) return;
    setState(() => _history = history);
    await context.push(
      Uri(
        path: AppRoutes.searchResults,
        queryParameters: {'q': keyword},
      ).toString(),
    );
    if (!mounted) return;
    setState(() => _history = store.load());
  }

  Future<void> _clearHistory() async {
    final store = await _resolveHistoryStore();
    await store.clear();
    if (!mounted) return;
    setState(() => _history = const []);
  }

  @override
  void dispose() {
    _historyStore?.removeListener(_handleHistoryChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentKeywords =
        widget.recentKeywords ??
        context.watch<StartupProvider?>()?.recentKeywords ??
        const <String>[];
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (_history.isNotEmpty)
            SearchKeywordSection(
              title: '历史搜索',
              keywords: _history,
              trailing: TextButton(
                onPressed: _clearHistory,
                child: const Text('清空'),
              ),
              onSelected: _search,
            ),
          if (recentKeywords.isNotEmpty)
            SearchKeywordSection(
              title: '近期热搜',
              keywords: recentKeywords,
              onSelected: _search,
            ),
        ],
      ),
    );
  }
}
