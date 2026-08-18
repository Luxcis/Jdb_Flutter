import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/review_api.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/core/widgets/star_rating.dart';
import 'package:provider/provider.dart';

/// 短评卡片：评价内容上方展示影片信息区（数据驱动，仅评论携带影片信息时渲染）。
class ReviewTile extends StatefulWidget {
  const ReviewTile({super.key, required this.review});

  final Review review;

  @override
  State<ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<ReviewTile> {
  late bool _liked;
  late int _likedCount;
  bool _liking = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.review.liked;
    _likedCount = widget.review.likedCount;
  }

  @override
  void didUpdateWidget(ReviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review != widget.review) {
      _liked = widget.review.liked;
      _likedCount = widget.review.likedCount;
    }
  }

  Future<void> _handleLikeTap() async {
    final movie = widget.review.movie;
    if (movie == null) {
      _showSnackBar('无法点赞');
      return;
    }
    if (_liked || _liking) return;

    final AuthProvider? auth;
    try {
      auth = context.read<AuthProvider>();
    } on ProviderNotFoundException {
      auth = null;
    }
    if (auth == null || !auth.isLogged) {
      _showSnackBar('请先登录', actionLabel: '去登录', onAction: () {
        context.push('/login');
      });
      return;
    }

    final api = ApiClient.instanceOrNull;
    if (api == null) {
      _showSnackBar('点赞失败，请重试');
      return;
    }
    setState(() => _liking = true);
    try {
      await ReviewApi(api).likeReview(
        movieId: movie.id,
        reviewId: widget.review.id,
      );
      if (!mounted) return;
      setState(() {
        _liked = true;
        _likedCount += 1;
      });
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('点赞失败，请重试');
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  void _showSnackBar(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final authorName = widget.review.author?.name ?? '';
    final movie = widget.review.movie;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (movie != null)
          _MovieHeader(
            movie: movie,
            onTap: () => context.push('/movie/${movie.id}'),
          ),
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
            if (widget.review.watchedCount > 0)
              Expanded(
                child: Text(
                  '看过${widget.review.watchedCount}部影片',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              const Spacer(),
            if (widget.review.score != null)
              StarRating(
                score: widget.review.score!,
                semanticLabel: '$authorName 短评评分',
                size: 17,
              ),
          ],
        ),
        if (widget.review.content != null && widget.review.content!.isNotEmpty)
          _ExpandableReviewContent(
            text: widget.review.content!,
            style: textTheme.bodyLarge,
          ),
        _LikeRow(
          liked: _liked,
          likedCount: _likedCount,
          liking: _liking,
          createdAt: widget.review.createdAt,
          onTap: _handleLikeTap,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: content,
    );
  }
}

/// 评论内容：超过 5 行自动截断，提供展开/收起控制。
class _ExpandableReviewContent extends StatefulWidget {
  const _ExpandableReviewContent({required this.text, required this.style});

  static const maxLines = 5;

  final String text;
  final TextStyle? style;

  @override
  State<_ExpandableReviewContent> createState() =>
      _ExpandableReviewContentState();
}

class _ExpandableReviewContentState extends State<_ExpandableReviewContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: _ExpandableReviewContent.maxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        if (!textPainter.didExceedMaxLines) {
          return Text(widget.text, style: widget.style);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: _expanded ? null : _ExpandableReviewContent.maxLines,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key(_expanded ? 'review-collapse' : 'review-expand'),
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                  textStyle: Theme.of(context).textTheme.bodySmall,
                ),
                child: Text(_expanded ? '收起' : '展开'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MovieHeader extends StatelessWidget {
  const _MovieHeader({required this.movie, required this.onTap});

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
class _LikeRow extends StatelessWidget {
  const _LikeRow({
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
