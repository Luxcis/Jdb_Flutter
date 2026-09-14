import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/review_api.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/widgets/review/expandable_review_content.dart';
import 'package:jade/core/widgets/review/review_tile_content.dart';
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

    AuthProvider? auth;
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
      _showSnackBar('你已经点过赞了');
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
          ReviewMovieHeader(
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
          ExpandableReviewContent(
            text: widget.review.content!,
            style: textTheme.bodyLarge,
          ),
        ReviewLikeRow(
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
