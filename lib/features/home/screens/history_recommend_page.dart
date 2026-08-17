import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/entity_list_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/home/models/recommend_period.dart';
import 'package:jade/features/home/services/history_recommend_service.dart';

/// 往期推荐列表页。
class HistoryRecommendPage extends StatefulWidget {
  const HistoryRecommendPage({super.key, this.dataSource});

  final RecommendPeriodDataSource? dataSource;

  @override
  State<HistoryRecommendPage> createState() => _HistoryRecommendPageState();
}

class _HistoryRecommendPageState extends State<HistoryRecommendPage> {
  late final RecommendPeriodDataSource _dataSource;
  late final PaginationController<RecommendPeriod> _controller;

  @override
  void initState() {
    super.initState();
    _dataSource =
        widget.dataSource ??
        switch (ApiClient.instanceOrNull) {
          final api? => HistoryRecommendService(api),
          null => const UnavailableRecommendPeriodDataSource(),
        };
    _controller = PaginationController<RecommendPeriod>(
      fetch: (page) => _dataSource.getPeriods(page: page),
    )..fetchMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('往期推荐')),
      body: PaginatedListView<RecommendPeriod>(
        controller: _controller,
        emptyMessage: '暂无往期推荐',
        itemBuilder: (context, item) {
          return EntityListTile(
            name: '第${item.period}期(${_formatDay(item.createdAt)})',
            count: item.moviesCount,
            onTap: () => context.push(
              AppRoutes.historyRecommendDetailLocation('${item.period}'),
            ),
          );
        },
      ),
    );
  }
}

/// 将 ISO 8601 时间格式化为本地日期 `YYYY-MM-DD`；解析失败返回空串。
String _formatDay(String? iso) {
  final time = iso == null ? null : DateTime.tryParse(iso);
  if (time == null) return '';
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
