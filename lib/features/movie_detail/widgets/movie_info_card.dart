import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/star_rating.dart';
import 'package:jade/features/movie_detail/widgets/movie_review_actions.dart';
import 'package:jade/features/movie_detail/widgets/top_ranking_tile.dart';

/// 影片信息卡：番号 + 元数据 + 评分 + 榜单 + 操作按钮 + 想看/看过人数。
class MovieInfoCard extends StatelessWidget {
  const MovieInfoCard({
    super.key,
    required this.detail,
    required this.review,
    required this.reviewMutationLoading,
    required this.onWantWatch,
    required this.onWatched,
    required this.onDeleteReview,
    required this.onSaveToList,
  });

  final MovieDetail detail;
  final Review? review;
  final bool reviewMutationLoading;
  final VoidCallback onWantWatch;
  final VoidCallback onWatched;
  final VoidCallback onDeleteReview;
  final VoidCallback onSaveToList;

  @override
  Widget build(BuildContext context) {
    final metadata =
        <({String label, String? value, String? category, String? id})>[
          (label: '发行日期', value: detail.releaseDate, category: null, id: null),
          (
            label: '时长',
            value: detail.duration == null ? null : '${detail.duration}分钟',
            category: null,
            id: null,
          ),
          (
            label: '导演',
            value: detail.director,
            category: 'd',
            id: detail.directorId,
          ),
          (label: '片商', value: detail.maker, category: 'm', id: detail.makerId),
          (
            label: '发行商',
            value: detail.publisher,
            category: 'p',
            id: detail.publisherId,
          ),
          (
            label: '系列',
            value: detail.series,
            category: 's',
            id: detail.seriesId,
          ),
        ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: const Key('movie-detail-info-column'),
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            MovieMetadataLine(
              label: '番号',
              value: detail.number,
              onTap: _commonListCallback(
                context,
                label: '番号',
                value: detail.numberLetter,
                category: 'c',
                id: detail.numberLetter,
              ),
            ),
            for (final item in metadata)
              if (item.value != null && item.value!.isNotEmpty)
                MovieMetadataLine(
                  label: item.label,
                  value: item.value!,
                  onTap: _commonListCallback(
                    context,
                    label: item.label,
                    value: item.value,
                    category: item.category,
                    id: item.id,
                  ),
                ),
            if (detail.score != null)
              Row(
                spacing: 6,
                children: [
                  const Text('评分: '),
                  StarRating(score: detail.score!, semanticLabel: '影片评分'),
                  Text(detail.score!.toString()),
                ],
              ),
            for (final ranking in detail.topRankings)
              if ((ranking.title ?? '').isNotEmpty)
                TopRankingTile(
                  ranking: ranking.ranking,
                  title: ranking.title ?? '',
                ),
            MovieReviewActions(
              key: const Key('movie-detail-actions'),
              review: review,
              loading: reviewMutationLoading,
              onWantWatch: onWantWatch,
              onWatched: onWatched,
              onDelete: onDeleteReview,
              onSaveToList: onSaveToList,
            ),
            Divider(
              key: const Key('movie-detail-actions-divider'),
              height: 12,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Text(
              '${detail.wantWatchCount}人想看，${detail.watchedCount}人看过',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _commonListCallback(
    BuildContext context, {
    required String label,
    required String? value,
    required String? category,
    required String? id,
  }) {
    final targetValue = value?.trim();
    final targetCategory = category?.trim();
    final targetId = id?.trim();
    if (targetValue == null ||
        targetValue.isEmpty ||
        targetCategory == null ||
        targetCategory.isEmpty ||
        targetId == null ||
        targetId.isEmpty) {
      return null;
    }

    return () => context.push(
      Uri(
        path: AppRoutes.commonList,
        queryParameters: {
          'title': '$label - $targetValue',
          'type': '${detail.type}',
          'category': targetCategory,
          'id': targetId,
        },
      ).toString(),
    );
  }
}

/// 元数据行：标签 + 值（值可点击跳转公共列表）。
class MovieMetadataLine extends StatelessWidget {
  const MovieMetadataLine({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = Theme.of(context).colorScheme.onSurface;
    final textStyle = DefaultTextStyle.of(
      context,
    ).style.copyWith(color: foregroundColor);
    final valueText = Text(
      value,
      style: textStyle.copyWith(
        decoration: onTap == null ? null : TextDecoration.underline,
        decorationColor: foregroundColor,
      ),
    );
    final valueWidget = onTap == null
        ? valueText
        : Semantics(
            button: true,
            label: '查看$value的$label影片列表',
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: valueText,
                ),
              ),
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text('$label:', style: textStyle),
        Flexible(child: valueWidget),
      ],
    );
  }
}
