import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/empty_state.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/features/home/services/history_recommend_service.dart';
import 'package:jade/features/home/widgets/recommend_movie_card.dart';

/// 某一期推荐影片列表页。
class HistoryRecommendDetailPage extends StatefulWidget {
  const HistoryRecommendDetailPage({
    super.key,
    required this.period,
    this.dataSource,
  });

  /// 期号。
  final String period;

  final RecommendPeriodDataSource? dataSource;

  @override
  State<HistoryRecommendDetailPage> createState() =>
      _HistoryRecommendDetailPageState();
}

class _HistoryRecommendDetailPageState
    extends State<HistoryRecommendDetailPage> {
  late final RecommendPeriodDataSource _dataSource;
  List<MovieSummary>? _movies;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _dataSource =
        widget.dataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => HistoryRecommendService(api),
          null => const UnavailableRecommendPeriodDataSource(),
        };
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _movies = null;
      _error = null;
    });
    try {
      final movies = await _dataSource.getMovies(widget.period);
      if (!mounted) return;
      setState(() => _movies = movies);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('第${widget.period}期')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ErrorRetryWidget(message: _error.toString(), onRetry: _load);
    }
    final movies = _movies;
    if (movies == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (movies.isEmpty) return const EmptyState(message: '本期暂无影片');
    return ListView.separated(
      itemCount: movies.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemBuilder: (context, index) => RecommendMovieCard(movie: movies[index]),
    );
  }
}
