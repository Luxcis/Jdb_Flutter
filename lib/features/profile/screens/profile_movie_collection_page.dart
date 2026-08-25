import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/filter_drawer.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

class ProfileMovieCollectionPage extends StatefulWidget {
  const ProfileMovieCollectionPage({
    super.key,
    required this.title,
    this.filterButton = false,
  });

  final String title;
  final bool filterButton;

  @override
  State<ProfileMovieCollectionPage> createState() =>
      _ProfileMovieCollectionPageState();
}

class _ProfileMovieCollectionPageState extends State<ProfileMovieCollectionPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final PaginationController<MovieSummary> _controller;
  static const _tabs = ['全部', '有码', '无码', '欧美', 'FC2', '动漫'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _controller = PaginationController<MovieSummary>(
      fetch: (page) async =>
          const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0),
    )..fetchMore();
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
        actions: [
          if (widget.filterButton)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.filter_list),
                tooltip: '筛选',
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      endDrawer: const FilterDrawer(
        schema: FilterSchema(
          groups: [
            FilterGroup(
              label: '状态',
              items: [
                (label: '全部', value: 'all'),
                (label: '可播放', value: 'playable'),
                (label: '含磁链', value: 'magnet'),
                (label: '字幕', value: 'subtitle'),
              ],
            ),
          ],
        ),
        onChanged: _noopFilter,
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((_) => MovieGridView(controller: _controller))
            .toList(growable: false),
      ),
    );
  }
}

void _noopFilter(Map<String, String> _) {}
