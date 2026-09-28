import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, this.showTitle = true});

  final MovieSummary movie;
  final bool showTitle;

  String get _coverImageUrl {
    final thumbUrl = movie.thumbUrl;
    if (thumbUrl != null && thumbUrl.isNotEmpty) return thumbUrl;
    return movie.coverUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Semantics(
      button: true,
      label: movie.title,
      child: InkWell(
        onTap: () => context.push('/movie/${movie.id}'),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: MovieCoverImage(
                    // 卡片语义由外层 Semantics(button) 统一播报，避免标题重复朗读。
                    _coverImageUrl,
                    variant: MovieImageVariant.thumbnail,
                    fit: BoxFit.contain,
                    memCacheWidth: 360,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showTitle) ...[
                      Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      movie.number,
                      style: textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
