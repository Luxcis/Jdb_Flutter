import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_select.dart';
import 'package:jade/core/widgets/filter_drawer.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/features/categories/services/category_service.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final tabs = ['有码', '无码', '欧美', 'FC2', '动漫'];
  final types = [1, 2, 3, 5, 6];
  var _sortBy = 'date';
  final _sortOptions = [
    ('最新', 'date'),
    ('热门', 'hot'),
    ('评分', 'rating'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PaginationController<MovieSummary> _buildCtrl(int type) {
    return PaginationController(fetch: (page) async {
      final api = ApiClient.instanceOrNull;
      if (api == null) {
        return const PagedResult(
            items: [], currentPage: 1, totalPages: 1, total: 0);
      }
      return CategoryService(api)
          .getMovies(type: type, sortBy: _sortBy, page: page);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('类别'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          Row(
            children: [
              SortSelect<(String, String)>(
                options: _sortOptions
                    .map((o) => (label: o.$1, value: o))
                    .toList(),
                value: _sortOptions.firstWhere((o) => o.$2 == _sortBy),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _sortBy = v.$2);
                  }
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: types
                  .map((t) => MovieGridView(controller: _buildCtrl(t)))
                  .toList(),
            ),
          ),
        ],
      ),
      endDrawer: FilterDrawer(
        schema: const FilterSchema(groups: []),
        onChanged: (_) {},
      ),
    );
  }
}
