import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/cached_image.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, this.onTap});
  final MovieSummary movie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: CachedImage(movie.coverUrl)),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(movie.number,
                    style: textTheme.labelSmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
