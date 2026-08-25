import 'package:flutter/material.dart';
import 'package:jade/core/widgets/search_entry.dart';
import 'package:jade/features/rankings/models/top250_filter.dart';
import 'package:jade/features/rankings/widgets/rank_tabs.dart';
import 'package:jade/features/rankings/widgets/top250_filter_sheet.dart';
import 'package:jade/features/rankings/widgets/top250_tab.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key, this.initialTabIndex = 2})
    : assert(initialTabIndex >= 0 && initialTabIndex < 6);

  final int initialTabIndex;

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage>
    with TickerProviderStateMixin {
  static const tabs = ['Top250', '看热播', '有码', '无码', '欧美', 'FC2'];

  late final TabController _tabController;
  var _top250Filter = const Top250Filter();
  late int _selectedTabIndex;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _tabController = TabController(
      length: tabs.length,
      initialIndex: widget.initialTabIndex,
      vsync: this,
    );
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void didUpdateWidget(covariant RankingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex == widget.initialTabIndex ||
        _tabController.index == widget.initialTabIndex) {
      return;
    }
    _tabController.index = widget.initialTabIndex;
  }

  void _handleTabChanged() {
    final index = _tabController.index;
    if (!mounted || _selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
  }

  void _showTop250Filter() {
    final sheetHeight = MediaQuery.sizeOf(context).height * 2 / 3;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints.tightFor(height: sheetHeight),
      builder: (_) => Top250FilterSheet(
        value: _top250Filter,
        onChanged: (value) => setState(() => _top250Filter = value),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('排行榜'),
        actions: [
          if (_selectedTabIndex == 0)
            IconButton(
              tooltip: '筛选 Top250',
              onPressed: _showTop250Filter,
              icon: const Icon(Icons.filter_alt_outlined),
            ),
          const SearchIconButton(),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Top250Tab(filter: _top250Filter),
          const HotPlayTab(),
          const RankTab(type: '0'),
          const RankTab(type: '1'),
          const RankTab(type: '2'),
          const RankTab(type: '3'),
        ],
      ),
    );
  }
}
