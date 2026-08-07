import 'package:flutter/material.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/directors/services/director_service.dart';

class DirectorsPage extends StatefulWidget {
  const DirectorsPage({super.key, this.dataSource});

  final DirectorDataSource? dataSource;

  @override
  State<DirectorsPage> createState() => _DirectorsPageState();
}

class _DirectorsPageState extends State<DirectorsPage>
    with TickerProviderStateMixin {
  static const tabs = ['有码', '欧美'];
  static const types = ['0', '2'];

  late final TabController _tabController;
  late final DirectorDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _dataSource =
        widget.dataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => DirectorService(api),
          null => const UnavailableDirectorDataSource(),
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
        title: const Text('导演'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in tabs) Tab(text: tab)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final type in types)
            _DirectorsTab<Director>(
              fetchPage: (page) => _dataSource.getDirectors(
                type: int.parse(type),
                page: page,
              ),
              emptyMessage: '暂无导演',
              itemBuilder: (context, item) => EntityListTile(
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
        ],
      ),
    );
  }
}

class _DirectorsTab<T> extends StatefulWidget {
  const _DirectorsTab({
    required this.fetchPage,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final Future<PagedResult<T>> Function(int page) fetchPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  @override
  State<_DirectorsTab<T>> createState() => _DirectorsTabState<T>();
}

class _DirectorsTabState<T> extends State<_DirectorsTab<T>>
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
