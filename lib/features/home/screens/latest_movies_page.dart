import 'package:flutter/material.dart';
import 'package:jade/features/home/services/latest_movies_service.dart';
import 'package:jade/features/home/widgets/latest_type_tab.dart';

typedef _MovieTypeTab = ({String label, String value});

class LatestMoviesPage extends StatefulWidget {
  const LatestMoviesPage({
    super.key,
    this.section = 'latest',
    this.title = '最新影片',
    this.dataSource,
  });

  final String section;
  final String title;
  final LatestMoviesDataSource? dataSource;

  @override
  State<LatestMoviesPage> createState() => _LatestMoviesPageState();
}

class _LatestMoviesPageState extends State<LatestMoviesPage>
    with TickerProviderStateMixin {
  static const _tabs = <_MovieTypeTab>[
    (label: '全部', value: 'all'),
    (label: '有码', value: '0'),
    (label: '无码', value: '1'),
    (label: '欧美', value: '2'),
    (label: 'FC2', value: '3'),
    (label: '动漫', value: '4'),
  ];

  late final TabController _tabController;

  String get _defaultFilter =>
      widget.section == 'magnets' ? 'magnets' : 'can_play';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
          tabs: [for (final tab in _tabs) Tab(text: tab.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final tab in _tabs)
            LatestTypeTab(
              key: PageStorageKey<String>(tab.value),
              type: tab.value,
              defaultFilter: _defaultFilter,
              dataSource: widget.dataSource,
            ),
        ],
      ),
    );
  }
}
