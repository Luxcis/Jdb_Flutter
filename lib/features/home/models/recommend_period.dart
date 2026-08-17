import 'package:jade/core/network/api_data.dart';

/// 推荐周期（往期推荐列表项）。
class RecommendPeriod {
  const RecommendPeriod({
    required this.period,
    required this.moviesCount,
    this.viewsCount = 0,
    this.createdAt,
  });

  /// 期号。
  final int period;

  /// 该期收录的影片数量。
  final int moviesCount;

  /// 浏览次数。
  final int viewsCount;

  /// 创建时间（ISO 8601）。
  final String? createdAt;

  factory RecommendPeriod.fromJson(Map<String, dynamic> json) =>
      RecommendPeriod(
        period: apiInt(json['period'], 0),
        moviesCount: apiInt(
          json['movies_count'] ?? json['moviesCount'],
          0,
        ),
        viewsCount: apiInt(json['views_count'] ?? json['viewsCount'], 0),
        createdAt: apiString(json['created_at'] ?? json['createdAt']),
      );
}
