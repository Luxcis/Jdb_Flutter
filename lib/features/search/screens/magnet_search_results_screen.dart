import 'package:flutter/material.dart';
import 'package:jade/features/search/services/magnet_search_service.dart';
import 'package:jade/features/search/services/search_history_store.dart';

class MagnetSearchResultsPage extends StatelessWidget {
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
  Widget build(BuildContext context) => Scaffold(body: Text(query));
}
