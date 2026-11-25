import 'package:flutter/material.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

typedef EntityTileBuilder<T> = Widget Function(BuildContext context, T item);

/// 单个 Tab 的配置：标签文案、分页数据源与条目构造器。
///
/// [emptyMessage] 为空时使用 [EntityTabListScreen.emptyMessage]，
/// 用于同一页面内不同 Tab 需要不同空态文案的场景（如系列页的番号/系列）。
class EntityTabSpec<T> {
  const EntityTabSpec({
    required this.label,
    required this.fetch,
    required this.tile,
    this.emptyMessage,
  });

  final String label;
  final PageFetcher<T> fetch;
  final EntityTileBuilder<T> tile;
  final String? emptyMessage;
}

/// 通用「Tab + 分页列表」屏。
///
/// 片商、导演、系列等实体列表页共用：各 feature 只提供数据源与 tile 构造，
/// 分页、加载/空态/错误态与 Tab 切换时的列表保活统一在这里实现。
class EntityTabListScreen<T> extends StatefulWidget {
  const EntityTabListScreen({
    super.key,
    required this.title,
    required this.emptyMessage,
    required this.tabs,
  }) : assert(tabs.length > 0, 'EntityTabListScreen 至少需要一个 Tab');

  final String title;
  final String emptyMessage;
  final List<EntityTabSpec<T>> tabs;

  @override
  State<EntityTabListScreen<T>> createState() => _EntityTabListScreenState<T>();
}

class _EntityTabListScreenState<T> extends State<EntityTabListScreen<T>>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 控制器长度直接取 Tab 配置数量，TabBar 与 TabBarView 由同一列表生成，
    // 从结构上避免两者长度不一致。
    _tabController = TabController(length: widget.tabs.length, vsync: this);
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
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in widget.tabs) Tab(text: tab.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final tab in widget.tabs)
            _EntityTabBody<T>(
              fetchPage: tab.fetch,
              itemBuilder: tab.tile,
              emptyMessage: tab.emptyMessage ?? widget.emptyMessage,
            ),
        ],
      ),
    );
  }
}

class _EntityTabBody<T> extends StatefulWidget {
  const _EntityTabBody({
    required this.fetchPage,
    required this.itemBuilder,
    required this.emptyMessage,
  });

  final PageFetcher<T> fetchPage;
  final EntityTileBuilder<T> itemBuilder;
  final String emptyMessage;

  @override
  State<_EntityTabBody<T>> createState() => _EntityTabBodyState<T>();
}

class _EntityTabBodyState<T> extends State<_EntityTabBody<T>>
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
