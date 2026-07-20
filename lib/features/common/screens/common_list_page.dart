import 'package:flutter/material.dart';
import 'package:jade/core/widgets/movie_grid_view.dart';
import 'package:jade/core/widgets/sort_segmented.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';

class CommonListPage extends StatefulWidget {
  final String title;
  final Future<PagedResult<MovieSummary>> Function(int page) dataSource;

  const CommonListPage({
    super.key,
    required this.title,
    required this.dataSource,
  });

  @override
  State<CommonListPage> createState() => _CommonListPageState();
}

class _CommonListPageState extends State<CommonListPage> {
  var _filter = 'all';
  late final _ctrl = PaginationController<MovieSummary>(
    fetch: widget.dataSource,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.fetchMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          SortSegmented<String>(
            options: const [
              (label: '全部', value: 'all'),
              (label: '可播放', value: 'playable'),
              (label: '含磁链', value: 'magnet'),
              (label: '字幕', value: 'subtitle'),
            ],
            value: _filter,
            onChanged: (v) {
              _filter = v;
              _ctrl.refresh();
            },
          ),
          Expanded(child: MovieGridView(controller: _ctrl)),
        ],
      ),
    );
  }
}
