import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/tag.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/image_gallery_viewer.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/movie_screenshot_image.dart';
import 'package:jade/core/widgets/tag_chip.dart';
import 'package:jade/features/movie_detail/widgets/movie_section.dart';

/// 类别横滚区。
class MovieCategorySection extends StatelessWidget {
  const MovieCategorySection({super.key, required this.tags, required this.type});

  final List<Tag> tags;
  final int type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('movie-detail-categories'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '类别:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 4,
                children: [
                  for (final tag in tags)
                    TagChip(
                      label: tag.name,
                      compact: true,
                      onTap: tag.id.trim().isEmpty
                          ? null
                          : () => context.push(
                              Uri(
                                path: AppRoutes.commonList,
                                queryParameters: {
                                  'title': '类别 - ${tag.name}',
                                  'type': '$type',
                                  'category': 't',
                                  'id': tag.id.trim(),
                                },
                              ).toString(),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 演员横滚区。
class MovieActorSection extends StatelessWidget {
  const MovieActorSection({
    super.key,
    required this.actors,
    required this.onActorTap,
  });

  final List<ActorSummary> actors;

  List<ActorSummary> get _sortedActors {
    final sorted = [...actors]
      ..sort((a, b) => (a.gender ?? 0).compareTo(b.gender ?? 0));
    return sorted;
  }

  final ValueChanged<ActorSummary> onActorTap;

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedActors;
    final actorCardHeight = ActorCard.mainAxisExtent(context, 80);
    return MovieSection(
      title: '演员',
      height: actorCardHeight < 112 ? 112 : actorCardHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => SizedBox(
          width: 80,
          child: ActorCard(
            actor: sorted[index],
            onTap: () => onActorTap(sorted[index]),
          ),
        ),
      ),
    );
  }
}

/// 预告片 / 剧照区。
class MovieScreenshotSection extends StatelessWidget {
  const MovieScreenshotSection({
    super.key,
    required this.urls,
    required this.previewCoverUrl,
    required this.previewTitle,
    required this.onPreviewTap,
  });

  final List<String> urls;
  final String? previewCoverUrl;
  final String previewTitle;
  final VoidCallback onPreviewTap;

  @override
  Widget build(BuildContext context) {
    final hasPreview = previewCoverUrl != null;
    return MovieSection(
      title: '预告片 / 剧照',
      titleTrailing: urls.isEmpty ? null : '共 ${urls.length} 张',
      height: 164,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: urls.length + (hasPreview ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          if (index == 0 && hasPreview) {
            return Semantics(
              button: true,
              label: '播放《$previewTitle》预告片',
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Material(
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: const Key('movie-detail-preview'),
                    onTap: onPreviewTap,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MovieCoverImage(
                          previewCoverUrl!,
                          variant: MovieImageVariant.cover,
                          fit: BoxFit.cover,
                        ),
                        const Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x99000000),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                key: Key('movie-detail-preview-play-icon'),
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final screenshotIndex = index - (hasPreview ? 1 : 0);
          return Semantics(
            button: true,
            label: '查看剧照 ${screenshotIndex + 1}，共 ${urls.length} 张',
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Material(
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  key: Key('movie-detail-screenshot-$screenshotIndex'),
                  onTap: () => showDialog<void>(
                    context: context,
                    useSafeArea: false,
                    builder: (_) => ImageGalleryViewer(
                      urls: urls,
                      initialIndex: screenshotIndex,
                    ),
                  ),
                  child: MovieScreenshotImage(urls[screenshotIndex]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 影片横向行（「TA还出演过」「你可能也喜欢」）。
class MovieRowSection extends StatelessWidget {
  const MovieRowSection({super.key, required this.title, required this.movies});

  final String title;
  final List<MovieSummary> movies;

  @override
  Widget build(BuildContext context) {
    return MovieSection(
      title: title,
      height: 232,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: movies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, index) => SizedBox(
          width: 140,
          child: MovieCard(movie: movies[index], showTitle: false),
        ),
      ),
    );
  }
}
