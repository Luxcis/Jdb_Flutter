import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/features/profile/services/review_movies_service.dart';
import 'package:jade/features/profile/services/review_movies_tab_controller.dart';

typedef _MovieTypeTab = ({String label, String value});

/// 展示已认证用户指定状态的评鉴影片网格页。
///
/// 可通过 [dataSource] 注入数据源以复用页面或替换默认 API 实现。
class ProfileReviewMoviesPage extends StatefulWidget {
  /// 创建使用 [title]、[status] 及可选 [dataSource] 的评鉴影片页。
  const ProfileReviewMoviesPage({
    super.key,
    required this.title,
    required this.status,
    this.dataSource,
  });

  /// 显示在应用栏中的页面标题。
  final String title;

  /// 请求评鉴影片时使用的状态 wire value。
  final String status;

  /// 可选的评鉴影片数据源；未提供时使用默认 API 数据源。
  final ReviewMoviesDataSource? dataSource;

  @override
  State<ProfileReviewMoviesPage> createState() =>
      _ProfileReviewMoviesPageState();
}

class _ProfileReviewMoviesPageState extends State<ProfileReviewMoviesPage>
    with TickerProviderStateMixin {
  static const _tabs = <_MovieTypeTab>[
    (label: '全部', value: 'all'),
    (label: '有码', value: '0'),
    (label: '无码', value: '1'),
    (label: '欧美', value: '2'),
    (label: 'FC2', value: '3'),
    (label: '动漫', value: '4'),
  ];
  static const _sortOptions = [
    (label: '添加时间', value: 'create'),
    (label: '发行时间', value: 'release'),
  ];
  static const _orderOptions = [
    (label: '倒序', value: 'desc'),
    (label: '正序', value: 'asc'),
  ];

  late final TabController _tabController;
  late final ReviewMoviesDataSource _dataSource;
  late final List<ReviewMoviesTabController> _controllers;
  var _sortBy = 'create';
  var _orderBy = 'desc';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableReviewMoviesDataSource()
            : ReviewMoviesService(api));
    _controllers = [
      for (final tab in _tabs)
        ReviewMoviesTabController(
          status: widget.status,
          type: tab.value,
          sortBy: _sortBy,
          orderBy: _orderBy,
          source: _dataSource,
        ),
    ];
    _tabController.addListener(_initializeSelectedTab);
    unawaited(_controllers[_tabController.index].initialize());
  }

  void _initializeSelectedTab() {
    if (_tabController.indexIsChanging) return;
    unawaited(_controllers[_tabController.index].initialize());
  }

  void _changeSortBy(String value) {
    if (value == _sortBy) return;
    setState(() => _sortBy = value);
    _reloadInitializedTabs();
  }

  void _changeOrderBy(String value) {
    if (value == _orderBy) return;
    setState(() => _orderBy = value);
    _reloadInitializedTabs();
  }

  void _reloadInitializedTabs() {
    for (final controller in _controllers) {
      unawaited(controller.changeSorting(sortBy: _sortBy, orderBy: _orderBy));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_initializeSelectedTab);
    _tabController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
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
          tabs: [for (final tab in _tabs) Tab(text: tab.label)],
        ),
      ),
      body: Column(
        spacing: 4,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: SortSegmented<String>(
              key: const Key('profile-review-movies-sort'),
              compact: true,
              expanded: true,
              options: _sortOptions,
              value: _sortBy,
              onChanged: _changeSortBy,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: SortSegmented<String>(
              key: const Key('profile-review-movies-order'),
              compact: true,
              expanded: true,
              options: _orderOptions,
              value: _orderBy,
              onChanged: _changeOrderBy,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (var index = 0; index < _tabs.length; index++)
                  _ReviewMoviesTab(
                    key: PageStorageKey<String>(_tabs[index].value),
                    controller: _controllers[index],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMoviesTab extends StatefulWidget {
  const _ReviewMoviesTab({super.key, required this.controller});

  final ReviewMoviesTabController controller;

  @override
  State<_ReviewMoviesTab> createState() => _ReviewMoviesTabState();
}

class _ReviewMoviesTabState extends State<_ReviewMoviesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MovieGridView(
      key: Key('profile-review-movies-grid-${widget.controller.type}'),
      controller: widget.controller.movies,
    );
  }
}
