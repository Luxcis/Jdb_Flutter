import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/search_entry.dart';
import 'package:jade/features/categories/services/category_service.dart';
import 'package:jade/features/categories/services/category_tab_controller.dart';
import 'package:jade/features/categories/widgets/category_filter_sheet.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, this.dataSource});

  final CategoryDataSource? dataSource;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage>
    with TickerProviderStateMixin {
  static const tabs = ['有码', '无码', '欧美', 'FC2', '动漫'];

  late final TabController _tabController;
  late final List<CategoryTabController> _controllers;
  late final CategoryDataSource _source;
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _source =
        widget.dataSource ??
        (api != null
            ? CategoryService(api)
            : const UnavailableCategoryDataSource());
    _controllers = [
      for (var type = 0; type < tabs.length; type++)
        CategoryTabController(type: type, source: _source),
    ];
    _tabController = TabController(length: tabs.length, vsync: this)
      ..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (_selectedIndex == _tabController.index || !mounted) return;
    setState(() => _selectedIndex = _tabController.index);
  }

  void _showFilter() {
    final height = MediaQuery.sizeOf(context).height * 2 / 3;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints.tightFor(height: height),
      builder: (_) =>
          CategoryFilterSheet(controller: _controllers[_selectedIndex]),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
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
        title: const Text('类别'),
        actions: [
          IconButton(
            key: const Key('categories-filter-button'),
            tooltip: '筛选',
            onPressed: _showFilter,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          const SearchIconButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in tabs) Tab(text: tab)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final controller in _controllers)
            _CategoryTab(
              key: PageStorageKey<int>(controller.type),
              controller: controller,
            ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatefulWidget {
  const _CategoryTab({super.key, required this.controller});

  final CategoryTabController controller;

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MovieGridView(
      key: Key('category-tab-grid-${widget.controller.type}'),
      controller: widget.controller.movies,
    );
  }
}
