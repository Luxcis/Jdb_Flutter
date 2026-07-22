import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/actor_grid_view.dart';
import 'package:jade/core/widgets/filter_drawer.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/movie_list_tile.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:provider/provider.dart';

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

class ProfileFollowingPage extends StatefulWidget {
  const ProfileFollowingPage({super.key});

  @override
  State<ProfileFollowingPage> createState() => _ProfileFollowingPageState();
}

class _ProfileFollowingPageState extends State<ProfileFollowingPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['全部关注', '演员', '标签'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的关注'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabs
            .map(
              (_) => ListView.builder(
                itemCount: 0,
                itemBuilder: (_, i) => MovieListTile(
                  movie: MovieSummary(
                    id: '$i',
                    number: '-',
                    title: '-',
                    coverUrl: '',
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class ProfileFavoritesPage extends StatelessWidget {
  const ProfileFavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _CellScaffold(
      title: '我的收藏',
      cells: [
        _ProfileCell(
          title: '收藏的演员',
          icon: Icons.person_outline,
          route: AppRoutes.profileFavoritesActors,
        ),
        _ProfileCell(
          title: '收藏的片商',
          icon: Icons.business,
          route: AppRoutes.profileFavoritesMakers,
        ),
        _ProfileCell(
          title: '收藏的系列',
          icon: Icons.collections_bookmark,
          route: AppRoutes.profileFavoritesSeries,
        ),
        _ProfileCell(
          title: '收藏的导演',
          icon: Icons.person_search,
          route: AppRoutes.profileFavoritesDirectors,
        ),
        _ProfileCell(
          title: '收藏的番号',
          icon: Icons.confirmation_number_outlined,
          route: AppRoutes.profileFavoritesCodes,
        ),
        _ProfileCell(
          title: '清单',
          subtitle: '0部影片，被查看0次',
          icon: Icons.list_alt,
          route: AppRoutes.profileFavoritesLists,
        ),
      ],
    );
  }
}

class ProfileFavoriteActorsPage extends StatefulWidget {
  const ProfileFavoriteActorsPage({super.key});

  @override
  State<ProfileFavoriteActorsPage> createState() =>
      _ProfileFavoriteActorsPageState();
}

class _ProfileFavoriteActorsPageState extends State<ProfileFavoriteActorsPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final PaginationController<ActorSummary> _controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _controller = PaginationController<ActorSummary>(
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
    const tabs = ['全部', '有码', '无码', '欧美'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏的演员'),
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabs
            .map((_) => ActorGridView(controller: _controller))
            .toList(growable: false),
      ),
    );
  }
}

class ProfileNamedCollectionPage extends StatelessWidget {
  const ProfileNamedCollectionPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _CellScaffold(
      title: title,
      cells: List.generate(
        6,
        (i) => _ProfileCell(
          title: '$title ${i + 1}',
          subtitle: title.contains('清单') || title == '我的清单'
              ? '0部影片，被查看0次'
              : null,
          icon: Icons.chevron_right,
        ),
      ),
    );
  }
}

class ProfileInfoPage extends StatelessWidget {
  const ProfileInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CellScaffold(
      title: '个人资料',
      cells: [
        _ProfileCell(title: '电子邮箱', subtitle: '未填写', icon: Icons.email),
        _ProfileCell(
          title: '短评被举报次数',
          subtitle: '0次',
          icon: Icons.report_outlined,
        ),
        _ProfileCell(
          title: '短评被删次数',
          subtitle: '0次',
          icon: Icons.delete_outline,
        ),
        _ProfileCell(
          title: '禁言次数',
          subtitle: '禁言次数超过最大次数后封禁账号',
          icon: Icons.volume_off_outlined,
        ),
        _ProfileCell(
          title: '待审核/已通过订正数',
          subtitle: '订正功能来自网页版影片详情',
          icon: Icons.fact_check_outlined,
        ),
        _ProfileCell(title: '修改密码', icon: Icons.lock_outline),
        _ProfileCell(title: '修改用户名', icon: Icons.badge_outlined),
      ],
    );
  }
}

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final blurMovieImages = context.select<SettingsProvider, bool>(
      (settings) => settings.blurMovieImages,
    );
    final cells = <Widget>[
      const _ProfileCell(
        title: '外观模式',
        subtitle: '跟随系统',
        icon: Icons.brightness_6_outlined,
      ),
      SwitchListTile(
        secondary: const Icon(Icons.blur_on_outlined),
        title: const Text('影片图片模糊'),
        subtitle: const Text('模糊影片封面与剧照'),
        value: blurMovieImages,
        onChanged: context.read<SettingsProvider>().setBlurMovieImages,
      ),
      const _ProfileCell(
        title: '线路选择',
        subtitle: '自动',
        icon: Icons.swap_horiz,
      ),
      const _ProfileCell(
        title: '默认筛选标签',
        subtitle: '含磁链',
        icon: Icons.tune,
      ),
      const _ProfileCell(
        title: '清除缓存',
        icon: Icons.cleaning_services_outlined,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView.separated(
        itemCount: cells.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) => cells[index],
      ),
    );
  }
}

class _CellScaffold extends StatelessWidget {
  const _CellScaffold({required this.title, required this.cells});

  final String title;
  final List<_ProfileCell> cells;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView.separated(
      itemCount: cells.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => cells[i],
    ),
  );
}

class _ProfileCell extends StatelessWidget {
  const _ProfileCell({
    required this.title,
    required this.icon,
    this.subtitle,
    this.route,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? route;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: route == null ? null : () => context.push(route!),
  );
}

void _noopFilter(Map<String, String> _) {}
