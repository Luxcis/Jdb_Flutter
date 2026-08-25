import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';
import 'package:jade/features/search/services/search_entity_service.dart';
import 'package:jade/features/search/services/search_movie_service.dart';
import 'package:jade/features/search/services/search_page_session.dart';
import 'package:jade/features/search/widgets/search_movie_filter_bar.dart';

typedef EntityItemBuilder<T> = Widget Function(BuildContext context, T item);

/// 通用实体搜索 Tab（系列/片商/导演/清单/番号），分页加载。
class PaginatedEntitySearchTab<T> extends StatefulWidget {
  const PaginatedEntitySearchTab({
    super.key,
    required this.fetchPage,
    required this.idOf,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final Future<PagedResult<T>> Function(int page) fetchPage;
  final String Function(T item) idOf;
  final EntityItemBuilder<T> itemBuilder;
  final String emptyMessage;

  @override
  State<PaginatedEntitySearchTab<T>> createState() =>
      _PaginatedEntitySearchTabState<T>();
}

class _PaginatedEntitySearchTabState<T>
    extends State<PaginatedEntitySearchTab<T>>
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
    return PaginatedListView<T>(
      controller: _controller,
      itemBuilder: widget.itemBuilder,
      emptyMessage: widget.emptyMessage,
    );
  }
}

/// 影片搜索 Tab：筛选条 + 分页网格。
class MovieSearchTab extends StatefulWidget {
  const MovieSearchTab({super.key, required this.query, required this.dataSource});

  final String query;
  final SearchMovieDataSource dataSource;

  @override
  State<MovieSearchTab> createState() => _MovieSearchTabState();
}

class _MovieSearchTabState extends State<MovieSearchTab> {
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

/// 演员搜索 Tab：分页头像网格。
class ActorSearchTab extends StatefulWidget {
  const ActorSearchTab({super.key, required this.query, required this.dataSource});

  final String query;
  final SearchEntityDataSource dataSource;

  @override
  State<ActorSearchTab> createState() => _ActorSearchTabState();
}

class _ActorSearchTabState extends State<ActorSearchTab>
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

