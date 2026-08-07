import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/star_rating.dart';

/// 短评卡片：评价内容上方展示影片信息区（数据驱动，仅评论携带影片信息时渲染）。
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final authorName = review.author?.name ?? '';
    final movie = review.movie;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (movie != null) _MovieHeader(movie: movie),
        Row(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (authorName.isNotEmpty)
              Text(
                authorName,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            if (review.watchedCount > 0)
              Expanded(
                child: Text(
                  '看过${review.watchedCount}部影片',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              const Spacer(),
            if (review.score != null)
              StarRating(
                score: review.score!,
                semanticLabel: '$authorName 短评评分',
                size: 17,
              ),
          ],
        ),
        if (review.content != null && review.content!.isNotEmpty)
          Text(review.content!, style: textTheme.bodyLarge),
        Row(
          children: [
            Icon(
              Icons.thumb_up_alt_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              review.likedCount.toString(),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (review.createdAt != null)
              Text(
                review.createdAt!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );

    final tile = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: content,
    );
    if (movie == null) return tile;
    return InkWell(onTap: () => context.push('/movie/${movie.id}'), child: tile);
  }
}

class _MovieHeader extends StatelessWidget {
  const _MovieHeader({required this.movie});

  final ReviewMovie movie;

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

    return Column(
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
    );
  }
}
