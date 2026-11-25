import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/entity_tab_list_screen.dart';
import 'package:jade/features/series/models/series_letter.dart';
import 'package:jade/features/series/services/series_service.dart';
import 'package:jade/router/routes.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key, this.dataSource});

  final SeriesDataSource? dataSource;

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  /// Tab 文案与接口 type 的单一来源，避免两个平行常量列表不同步。
  static const _tabs = [
    (label: '有码', type: '0'),
    (label: '无码', type: '1'),
    (label: '欧美', type: '2'),
    (label: '动漫', type: '4'),
  ];

  late final SeriesDataSource _dataSource =
      widget.dataSource ?? SeriesService.resolve();

  @override
  Widget build(BuildContext context) {
    // 番号与系列是两种模型，故以 Object 作为 Tab 的公共条目类型，
    // tile 内再恢复为各自的强类型。
    return EntityTabListScreen<Object>(
      title: '系列',
      emptyMessage: '暂无系列',
      tabs: [
        EntityTabSpec<Object>(
          label: '番号',
          emptyMessage: '暂无番号',
          fetch: (page) => _dataSource.getLetters(page: page),
          tile: (context, item) {
            final letter = item as SeriesLetter;
            return EntityListTile(
              name: letter.letter,
              count: letter.videosCount,
              subtitle: letter.description,
              onTap: () => context.push(
                Uri(
                  path: AppRoutes.commonList,
                  queryParameters: {
                    'title': '番号 - ${letter.letter}',
                    'type': '${letter.type}',
                    'category': 'c',
                    'id': letter.id,
                  },
                ).toString(),
              ),
            );
          },
        ),
        for (final tab in _tabs)
          EntityTabSpec<Object>(
            label: tab.label,
            fetch: (page) => _dataSource.getSeries(type: tab.type, page: page),
            tile: (context, item) {
              final series = item as Series;
              return EntityListTile(
                name: series.name,
                count: series.movieCount,
                onTap: () => context.push(
                  Uri(
                    path: AppRoutes.commonList,
                    queryParameters: {
                      'title': '系列 - ${series.name}',
                      'type': '${series.type}',
                      'category': 's',
                      'id': series.id,
                    },
                  ).toString(),
                ),
              );
            },
          ),
      ],
    );
  }
}
