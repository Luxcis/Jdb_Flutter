import 'package:flutter/material.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/makers/services/maker_service.dart';

class MakersPage extends StatefulWidget {
  const MakersPage({super.key, this.dataSource});

  final MakerDataSource? dataSource;

  @override
  State<MakersPage> createState() => _MakersPageState();
}

class _MakersPageState extends State<MakersPage>
    with TickerProviderStateMixin {
  static const tabs = ['有码', '无码', '欧美', 'FC2', '动漫'];
  static const types = ['0', '1', '2', '3', '4'];

  late final TabController _tabController;
  late final MakerDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    _dataSource =
        widget.dataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => MakerService(api),
          null => const UnavailableMakerDataSource(),
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
        title: const Text('片商'),
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
            _MakersTab<Maker>(
              fetchPage: (page) => _dataSource.getMakers(
                type: int.parse(type),
                page: page,
              ),
              emptyMessage: '暂无片商',
              itemBuilder: (context, item) => EntityListTile(
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
        ],
      ),
    );
  }
}

class _MakersTab<T> extends StatefulWidget {
  const _MakersTab({
    required this.fetchPage,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final Future<PagedResult<T>> Function(int page) fetchPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;

  @override
  State<_MakersTab<T>> createState() => _MakersTabState<T>();
}

class _MakersTabState<T> extends State<_MakersTab<T>>
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
