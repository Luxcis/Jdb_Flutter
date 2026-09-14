import 'package:flutter/material.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';

/// 评论卡片头部的影片信息区，点击跳转影片详情。
class ReviewMovieHeader extends StatelessWidget {
  const ReviewMovieHeader({super.key, required this.movie, required this.onTap});

  final ReviewMovie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final thumbUrl = movie.thumbUrl;
    final number = movie.number ?? '';
    final releaseDate = movie.releaseDate ?? '';
    final meta = [
      if (number.isNotEmpty) number,
      if (releaseDate.isNotEmpty) releaseDate,
    ].join(' / ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbUrl != null && thumbUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: MovieCoverImage(
                    thumbUrl,
                    variant: MovieImageVariant.thumbnail,
                    width: 72,
                    height: 96,
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// 点赞行：点赞图标 + 数量 + 日期，点击触发点赞回调。
class ReviewLikeRow extends StatelessWidget {
  const ReviewLikeRow({
    super.key,
    required this.liked,
    required this.likedCount,
    required this.liking,
    required this.createdAt,
    required this.onTap,
  });

  final bool liked;
  final int likedCount;
  final bool liking;
  final String? createdAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        InkWell(
          key: const Key('review-like-button'),
          onTap: liking ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: liked ? '已点赞' : '点赞，当前 $likedCount 人已赞',
                  child: ExcludeSemantics(
                    child: Icon(
                      liked
                          ? Icons.thumb_up_alt
                          : Icons.thumb_up_alt_outlined,
                      key: liked
                          ? const Key('review-liked-icon')
                          : const Key('review-unliked-icon'),
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  likedCount.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (createdAt != null)
          Text(
            createdAt!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
