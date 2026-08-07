import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/series/models/series_letter.dart';
import 'package:jade/features/series/services/series_service.dart';

class SeriesPage extends StatefulWidget {
  const SeriesPage({super.key, this.dataSource});

  final SeriesDataSource? dataSource;

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage>
    with TickerProviderStateMixin {
  static const tabs = ['番号', '有码', '无码', '欧美', '动漫'];
  static const types = ['0', '1', '2', '4'];

  late final TabController _tabController;
  late final SeriesDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _dataSource =
        widget.dataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => SeriesService(api),
          null => const UnavailableSeriesDataSource(),
        };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系列'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in tabs) Tab(text: tab)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SeriesTab<SeriesLetter>(
            fetchPage: (page) => _dataSource.getLetters(page: page),
            emptyMessage: '暂无番号',
            itemBuilder: (context, item) => EntityListTile(
              name: item.letter,
              count: item.videosCount,
              subtitle: item.description,
              onTap: () => context.push(
                Uri(
                  path: AppRoutes.commonList,
                  queryParameters: {
                    'title': '番号 - ${item.letter}',
                    'type': '${item.type}',
                    'category': 'c',
                    'id': item.id,
                  },
                ).toString(),
              ),
            ),
          ),
          for (final type in types)
            _SeriesTab<Series>(
              fetchPage: (page) =>
                  _dataSource.getSeries(type: type, page: page),
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
        ],
      ),
    );
  }
}

class _SeriesTab<T> extends StatefulWidget {
  const _SeriesTab({
    required this.fetchPage,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final Future<PagedResult<T>> Function(int page) fetchPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  @override
  State<_SeriesTab<T>> createState() => _SeriesTabState<T>();
}

class _SeriesTabState<T> extends State<_SeriesTab<T>>
    with AutomaticKeepAliveClientMixin {
  late final PaginationController<T> _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaginationController<T>(fetch: widget.fetchPage)..fetchMore();
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
