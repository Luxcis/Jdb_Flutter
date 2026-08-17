import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/star_rating.dart';

/// 往期推荐影片卡片：占满整行宽，自上而下依次为封面、标题、五星评分。
class RecommendMovieCard extends StatelessWidget {
  const RecommendMovieCard({super.key, required this.movie});

  final MovieSummary movie;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/movie/${movie.id}'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: MovieCoverImage(
                  movie.coverUrl,
                  variant: MovieImageVariant.cover,
                  semanticLabel: movie.title,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  StarRating(score: movie.score ?? 0, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
