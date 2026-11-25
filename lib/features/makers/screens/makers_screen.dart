import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/entity_tab_list_screen.dart';
import 'package:jade/features/makers/services/maker_service.dart';
import 'package:jade/router/routes.dart';

class MakersScreen extends StatefulWidget {
  const MakersScreen({super.key, this.dataSource});

  final MakerDataSource? dataSource;

  @override
  State<MakersScreen> createState() => _MakersScreenState();
}

class _MakersScreenState extends State<MakersScreen> {
  /// Tab 文案与接口 type 的单一来源，避免两个平行常量列表不同步。
  static const _tabs = [
    (label: '有码', type: 0),
    (label: '无码', type: 1),
    (label: '欧美', type: 2),
    (label: 'FC2', type: 3),
    (label: '动漫', type: 4),
  ];

  late final MakerDataSource _dataSource =
      widget.dataSource ?? makerDataSource();

  @override
  Widget build(BuildContext context) {
    return EntityTabListScreen<Maker>(
      title: '片商',
      emptyMessage: '暂无片商',
      tabs: [
        for (final tab in _tabs)
          EntityTabSpec<Maker>(
            label: tab.label,
            fetch: (page) => _dataSource.getMakers(type: tab.type, page: page),
            tile: (context, item) => EntityListTile(
              name: item.name,
              count: item.movieCount,
              onTap: () => context.push(
                Uri(
                  path: AppRoutes.commonList,
                  queryParameters: {
                    'title': '片商 - ${item.name}',
                    'type': '${item.type}',
                    'category': 'm',
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
