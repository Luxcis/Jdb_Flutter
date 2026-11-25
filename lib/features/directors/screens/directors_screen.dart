import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/entity_tab_list_screen.dart';
import 'package:jade/features/directors/services/director_service.dart';
import 'package:jade/router/routes.dart';

class DirectorsScreen extends StatefulWidget {
  const DirectorsScreen({super.key, this.dataSource});

  final DirectorDataSource? dataSource;

  @override
  State<DirectorsScreen> createState() => _DirectorsScreenState();
}

class _DirectorsScreenState extends State<DirectorsScreen> {
  /// Tab 文案与接口 type 的单一来源，避免两个平行常量列表不同步。
  static const _tabs = [(label: '有码', type: 0), (label: '欧美', type: 2)];

  late final DirectorDataSource _dataSource =
      widget.dataSource ?? directorDataSource();

  @override
  Widget build(BuildContext context) {
    return EntityTabListScreen<Director>(
      title: '导演',
      emptyMessage: '暂无导演',
      tabs: [
        for (final tab in _tabs)
          EntityTabSpec<Director>(
            label: tab.label,
            fetch: (page) =>
                _dataSource.getDirectors(type: tab.type, page: page),
            tile: (context, item) => EntityListTile(
              name: item.name,
              count: item.movieCount,
              onTap: () => context.push(
                Uri(
                  path: AppRoutes.commonList,
                  queryParameters: {
                    'title': '导演 - ${item.name}',
                    'type': '${item.type}',
                    'category': 'd',
                    'id': item.id,
                  },
                ).toString(),
              ),
            ),
          ),
      ],
    );
  }
}
