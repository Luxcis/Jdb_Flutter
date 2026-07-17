import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/core/widgets/rating_badge.dart';

class MovieListTile extends StatelessWidget {
  const MovieListTile({
    super.key, required this.movie, this.rank, this.onTap,
  });
  final MovieSummary movie;
  final int? rank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 80, height: 100,
                    child: CachedImage(movie.coverUrl),
                  ),
                ),
                if (rank != null)
                  Positioned(top: 2, left: 2, child: RatingBadge(rank: rank!)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    '${movie.number}  ${movie.releaseDate ?? ''}',
                    style: textTheme.labelSmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
