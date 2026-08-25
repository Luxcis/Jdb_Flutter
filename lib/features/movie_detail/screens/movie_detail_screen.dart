import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/models/movie_review_sort.dart';
import 'package:jade/features/movie_detail/models/movie_review_status.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';
import 'package:jade/features/movie_detail/widgets/basic_info_widgets.dart';
import 'package:jade/features/movie_detail/widgets/save_to_list_sheet.dart';
import 'package:jade/features/movie_detail/widgets/watched_review_sheet.dart';

class MovieDetailPage extends StatefulWidget {
  const MovieDetailPage({super.key, required this.id});

  final String id;

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  MovieDetailService? _service;
  MovieDetail? _detail;
  List<Magnet> _magnets = [];
  Object? _magnetsError;
  bool _magnetsLoading = true;
  List<Review> _reviews = [];
  MovieReviewSort _reviewSort = MovieReviewSort.hotly;
  bool _reviewsLoading = false;
  List<ListModel> _relatedLists = [];
  Object? _relatedListsError;
  bool _relatedListsLoading = true;
  bool _loading = true;
  bool _saveToListOpening = false;
  Review? _currentReview;
  bool _reviewMutationLoading = false;
  int _reviewMutationGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _magnets = [];
      _magnetsError = null;
      _magnetsLoading = true;
      _reviews = [];
      _reviewSort = MovieReviewSort.hotly;
      _reviewsLoading = false;
      _relatedLists = [];
      _relatedListsError = null;
      _relatedListsLoading = true;
      _currentReview = null;
      _reviewMutationLoading = false;
    });
    try {
      final api = ApiClient.instanceOrNull;
      if (api == null) {
        setState(() {
          _error = '网络客户端未初始化';
          _loading = false;
        });
        return;
      }
      final service = MovieDetailService(api);
      final detail = await service.getDetail(widget.id);
      if (!mounted) return;
      setState(() {
        _service = service;
        _detail = detail;
        _currentReview = detail.review;
        _loading = false;
      });
      unawaited(_loadMagnets(service));
      unawaited(_loadReviews(service));
      unawaited(_loadRelatedLists(service));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMagnets(MovieDetailService service) async {
    if (mounted) {
      setState(() {
        _magnetsLoading = true;
        _magnetsError = null;
      });
    }
    try {
      final magnets = await service.getMagnets(widget.id);
      if (!mounted) return;
      setState(() {
        _magnets = magnets;
        _magnetsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _magnetsError = error;
        _magnetsLoading = false;
      });
    }
  }

  Future<void> _loadReviews(
    MovieDetailService service, {
    MovieReviewSort sort = MovieReviewSort.hotly,
  }) async {
    if (mounted) {
      setState(() {
        _reviewsLoading = true;
        _reviewSort = sort;
      });
    }
    try {
      final reviews = await service.getReviews(widget.id, sortBy: sort.value);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _reviewsLoading = false;
      });
    } catch (_) {
      // 短评继续沿用空状态，不影响本次磁链与相关清单错误处理。
      if (!mounted) return;
      setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _loadRelatedLists(MovieDetailService service) async {
    if (mounted) {
      setState(() {
        _relatedListsLoading = true;
        _relatedListsError = null;
      });
    }
    try {
      final lists = await service.getRelatedLists(widget.id);
      if (!mounted) return;
      setState(() {
        _relatedLists = lists;
        _relatedListsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _relatedListsError = error;
        _relatedListsLoading = false;
      });
    }
  }

  void _retryMagnets() {
    final service = _service;
    if (service != null) unawaited(_loadMagnets(service));
  }

  void _retryRelatedLists() {
    final service = _service;
    if (service != null) unawaited(_loadRelatedLists(service));
  }

  void _changeReviewSort(MovieReviewSort sort) {
    if (_reviewsLoading || _reviewSort == sort) return;
    final service = _service;
    if (service != null) unawaited(_loadReviews(service, sort: sort));
  }

  Future<void> _createOrUpdateReview(
    MovieReviewStatus status, {
    int? score,
    String? content,
  }) async {
    if (_reviewMutationLoading) return;
    final service = _service;
    if (service == null) return;
    setState(() => _reviewMutationLoading = true);
    try {
      final review = await service.createOrUpdateReview(
        movieId: widget.id,
        status: status,
        score: score,
        content: content,
      );
      if (!mounted) return;
      final generation = ++_reviewMutationGeneration;
      setState(() => _currentReview = review);
      unawaited(_refreshDetailAfterReview(generation));
    } on DioException catch (error) {
      if (_isAuthError(error)) return;
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _reviewMutationLoading = false);
      } else {
        _reviewMutationLoading = false;
      }
    }
  }

  Future<void> _deleteCurrentReview() async {
    if (_reviewMutationLoading) return;
    final service = _service;
    final review = _currentReview;
    if (service == null || review == null) return;
    setState(() => _reviewMutationLoading = true);
    try {
      await service.deleteReview(movieId: widget.id, reviewId: review.id);
      if (!mounted) return;
      final generation = ++_reviewMutationGeneration;
      setState(() => _currentReview = null);
      unawaited(_refreshDetailAfterReview(generation));
    } on DioException catch (error) {
      if (_isAuthError(error)) return;
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _reviewMutationLoading = false);
      } else {
        _reviewMutationLoading = false;
      }
    }
  }

  Future<void> _refreshDetailAfterReview(int generation) async {
    final service = _service;
    if (service == null) return;
    try {
      final detail = await service.getDetail(widget.id);
      if (!mounted || generation != _reviewMutationGeneration) return;
      setState(() {
        _detail = detail;
        _currentReview = detail.review;
      });
    } on DioException catch (error) {
      if (!mounted ||
          generation != _reviewMutationGeneration ||
          _isAuthError(error)) {
        return;
      }
      _showSnackBar('状态已更新，详情刷新失败');
    } catch (_) {
      if (mounted && generation == _reviewMutationGeneration) {
        _showSnackBar('状态已更新，详情刷新失败');
      }
    }
  }

  Future<void> _markWantWatch() async {
    try {
      await _createOrUpdateReview(MovieReviewStatus.wantWatch);
    } catch (_) {
      if (mounted) _showSnackBar('操作失败，请重试');
    }
  }

  Future<void> _submitWatchedReview({
    required int score,
    required String content,
  }) {
    return _createOrUpdateReview(
      MovieReviewStatus.watched,
      score: score,
      content: content,
    );
  }

  Future<void> _removeCurrentReview() async {
    try {
      await _deleteCurrentReview();
    } catch (_) {
      if (mounted) _showSnackBar('操作失败，请重试');
    }
  }

  Future<void> _openWatchedReviewSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => WatchedReviewSheet(
        onSubmit: ({required score, required content}) =>
            _submitWatchedReview(score: score, content: content),
      ),
    );
  }

  Future<void> _openSaveToListSheet() async {
    if (_saveToListOpening) return;
    final api = ApiClient.instanceOrNull;
    final service = _service ?? (api == null ? null : MovieDetailService(api));
    if (service == null) return;
    setState(() => _saveToListOpening = true);
    try {
      final lists = await service.getSimpleLists(widget.id);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => MovieSaveToListSheet(
          service: service,
          movieId: widget.id,
          initialLists: lists,
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      if (_isAuthError(error)) {
        return;
      }
      _showSnackBar('清单加载失败');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('清单加载失败');
    } finally {
      if (mounted) {
        setState(() => _saveToListOpening = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isAuthError(DioException error) {
    if (error.response?.statusCode == 401) return true;
    final apiError = error.error;
    if (apiError is ApiException) return apiError.isAuthError;
    final data = error.response?.data;
    if (data is Map) {
      final action = data['action'];
      return action == ApiErrorActions.jwtVerificationError ||
          action == ApiErrorActions.nonExistentUser;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: ErrorRetryWidget(message: _error!, onRetry: _load),
      );
    }

    final detail = _detail!;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              detail.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: DefaultTabController(
            length: 4,
            child: MovieDetailTabs(
              detail: detail,
              magnets: _magnets,
              magnetsError: _magnetsError,
              magnetsLoading: _magnetsLoading,
              onRetryMagnets: _retryMagnets,
              reviews: _reviews,
              reviewsLoading: _reviewsLoading,
              reviewSort: _reviewSort,
              onReviewSortChanged: _changeReviewSort,
              relatedLists: _relatedLists,
              relatedListsError: _relatedListsError,
              relatedListsLoading: _relatedListsLoading,
              onRetryRelatedLists: _retryRelatedLists,
              review: _currentReview,
              reviewMutationLoading: _reviewMutationLoading,
              onWantWatch: () => unawaited(_markWantWatch()),
              onWatched: () => unawaited(_openWatchedReviewSheet()),
              onDeleteReview: () => unawaited(_removeCurrentReview()),
              onSaveToList: _openSaveToListSheet,
              onPreviewTap: () => context.push(
                AppRoutes.moviePreviewLocation(detail.id),
                extra: MoviePreviewArgs(
                  movieId: detail.id,
                  title: detail.title,
                  videoUrl: MoviePreviewArgs.replaceHostWithLine(
                    detail.previewVideoUrl!,
                    ApiClient.instanceOrNull?.domainManager.currentUrl,
                  ),
                ),
              ),
              onActorTap: (actor) => context.push('/actor/${actor.id}'),
            ),
          ),
        ),
        if (_saveToListOpening)
          const Positioned.fill(
            child: ColoredBox(
              key: Key('movie-save-to-list-loading-overlay'),
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
