import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/tag.dart';
import 'package:jade/router/routes.dart';
import 'package:jade/core/widgets/actor_card.dart';
import 'package:jade/core/widgets/image_gallery_viewer.dart';
import 'package:jade/core/widgets/movie_card.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/movie_still_thumbnail.dart';
import 'package:jade/core/widgets/tag_chip.dart';
import 'package:jade/features/movie_detail/widgets/movie_section.dart';

/// 类别横滚区。
class MovieCategorySection extends StatelessWidget {
  const MovieCategorySection({
    super.key,
    required this.tags,
    required this.type,
  });

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

/// 正片 / 预告片 / 剧照区。
class MovieScreenshotSection extends StatelessWidget {
  const MovieScreenshotSection({
    super.key,
    required this.urls,
    required this.previewCoverUrl,
    required this.previewTitle,
    required this.onPreviewTap,
    required this.onlineCoverUrl,
    required this.onOnlineTap,
  });

  final List<String> urls;
  final String? previewCoverUrl;
  final String previewTitle;
  final VoidCallback onPreviewTap;

  /// 正片入口卡的封面（影片封面）。
  final String onlineCoverUrl;
  final VoidCallback onOnlineTap;

  @override
  Widget build(BuildContext context) {
    final hasPreview = previewCoverUrl != null;
    final playEntryCount = hasPreview ? 2 : 1;
    return MovieSection(
      title: '正片 / 预告片 / 剧照',
      titleTrailing: urls.isEmpty ? null : '共 ${urls.length} 张',
      height: 164,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: playEntryCount + urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          if (index == 0) {
            return _PlayEntryCard(
              cardKey: const Key('movie-detail-online'),
              iconKey: const Key('movie-detail-online-play-icon'),
              labelKey: const Key('movie-detail-online-label'),
              semanticsLabel: '播放《$previewTitle》正片',
              coverUrl: onlineCoverUrl,
              label: '正片',
              onTap: onOnlineTap,
            );
          }
          if (index == 1 && hasPreview) {
            return _PlayEntryCard(
              cardKey: const Key('movie-detail-preview'),
              iconKey: const Key('movie-detail-preview-play-icon'),
              labelKey: const Key('movie-detail-preview-label'),
              semanticsLabel: '播放《$previewTitle》预告片',
              coverUrl: previewCoverUrl!,
              label: '预告片',
              onTap: onPreviewTap,
            );
          }

          final screenshotIndex = index - playEntryCount;
          return Semantics(
            button: true,
            label: '查看剧照 ${screenshotIndex + 1}，共 ${urls.length} 张',
            child: MovieStillThumbnail(
              key: Key('movie-detail-screenshot-$screenshotIndex'),
              urls[screenshotIndex],
              onTap: () => showDialog<void>(
                context: context,
                useSafeArea: false,
                builder: (_) => ImageGalleryViewer(
                  urls: urls,
                  initialIndex: screenshotIndex,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 播放入口卡（正片 / 预告片）：封面图 + 中央播放图标 + 文本标识。
class _PlayEntryCard extends StatelessWidget {
  const _PlayEntryCard({
    required this.cardKey,
    required this.iconKey,
    required this.labelKey,
    required this.semanticsLabel,
    required this.coverUrl,
    required this.label,
    required this.onTap,
  });

  final Key cardKey;
  final Key iconKey;
  final Key labelKey;
  final String semanticsLabel;
  final String coverUrl;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: cardKey,
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MovieCoverImage(
                  coverUrl,
                  variant: MovieImageVariant.cover,
                  fit: BoxFit.cover,
                ),
                Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        key: iconKey,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xB3000000)],
                      ),
                    ),
                    child: Text(
                      label,
                      key: labelKey,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
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
