import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:jade/features/articles/models/article.dart';

class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article});

  final ArticleSummary article;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = article.coverUrl;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/articles/${article.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: coverUrl == null || coverUrl.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                          size: 40,
                        ),
                      )
                    : CachedImage(
                        coverUrl,
                        fit: BoxFit.cover,
                        semanticLabel: article.title,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          article.author ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      if (article.category != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            article.category!,
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        article.releasedAt ?? '',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
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
