import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/features/movie_detail/models/movie_preview_args.dart';
import 'package:jade/features/movie_detail/models/movie_review_sort.dart';
import 'package:jade/features/movie_detail/models/movie_review_status.dart';
import 'package:jade/features/movie_detail/services/detail_section_state.dart';
import 'package:jade/features/movie_detail/services/movie_detail_service.dart';
import 'package:jade/features/movie_detail/widgets/basic_info_widgets.dart';
import 'package:jade/features/movie_detail/widgets/save_to_list_sheet.dart';
import 'package:jade/features/movie_detail/widgets/watched_review_sheet.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  MovieDetailService? _service;
  MovieDetail? _detail;
  final ReviewStatusState _reviewStatus = ReviewStatusState();
  DetailSectionState<Magnet>? _magnetsState;
  ReviewSectionState? _reviewsState;
  DetailSectionState<ListModel>? _relatedListsState;
  bool _loading = true;
  bool _saveToListOpening = false;
  String? _error;
  int _reviewMutationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _recreateSections() {
    _magnetsState?.dispose();
    _reviewsState?.dispose();
    _relatedListsState?.dispose();
    _magnetsState = DetailSectionState();
    _reviewsState = ReviewSectionState();
    _relatedListsState = DetailSectionState();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _recreateSections();
    _reviewStatus
      ..setMutationLoading(false)
      ..updateReview(null);
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
        _loading = false;
      });
      _reviewStatus
        ..setMutationLoading(false)
        ..updateReview(detail.review);
      unawaited(_loadMagnetsSection(service));
      unawaited(_loadReviewsSection(service));
      unawaited(_loadRelatedListsSection(service));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMagnetsSection(MovieDetailService service) async {
    final state = _magnetsState;
    if (state == null) return;
    state.beginLoad();
    try {
      state.loaded(await service.getMagnets(widget.id));
    } catch (error) {
      debugPrint('movie_detail magnets load failed: $error');
      state.failed(error);
    }
  }

  Future<void> _loadReviewsSection(
    MovieDetailService service, {
    MovieReviewSort sort = MovieReviewSort.hotly,
  }) async {
    final state = _reviewsState;
    if (state == null) return;
    state.beginLoad(sort);
    try {
      state.loaded(await service.getReviews(widget.id, sortBy: sort.value));
    } catch (error, stackTrace) {
      // 短评沿用空状态，不影响磁链与相关清单的错误处理；但保留失败日志。
      debugPrint('movie_detail reviews load failed: $error\n$stackTrace');
      state.failedAsEmpty();
    }
  }

  Future<void> _loadRelatedListsSection(MovieDetailService service) async {
    final state = _relatedListsState;
    if (state == null) return;
    state.beginLoad();
    try {
      state.loaded(await service.getRelatedLists(widget.id));
    } catch (error) {
      debugPrint('movie_detail related-lists load failed: $error');
      state.failed(error);
    }
  }

  void _retryMagnets() {
    final service = _service;
    if (_magnetsState != null && service != null) {
      unawaited(_loadMagnetsSection(service));
    }
  }

  void _retryRelatedLists() {
    final service = _service;
    if (_relatedListsState != null && service != null) {
      unawaited(_loadRelatedListsSection(service));
    }
  }

  void _changeReviewSort(MovieReviewSort sort) {
    final state = _reviewsState;
    final service = _service;
    if (state == null || state.loading || state.sort == sort) {
      return;
    }
    if (service != null) {
      unawaited(_loadReviewsSection(service, sort: sort));
    }
  }

  Future<void> _createOrUpdateReview(
    MovieReviewStatus status, {
    int? score,
    String? content,
  }) async {
    if (_reviewStatus.mutationLoading) return;
    final service = _service;
    if (service == null) return;
    _reviewStatus.setMutationLoading(true);
    try {
      final review = await service.createOrUpdateReview(
        movieId: widget.id,
        status: status,
        score: score,
        content: content,
      );
      if (!mounted) return;
      final generation = ++_reviewMutationGeneration;
      _reviewStatus.updateReview(review);
      unawaited(_refreshDetailAfterReview(generation));
    } on DioException catch (error) {
      if (_isAuthError(error)) return;
      rethrow;
    } finally {
      _reviewStatus.setMutationLoading(false);
    }
  }

  Future<void> _deleteCurrentReview() async {
    if (_reviewStatus.mutationLoading) return;
    final service = _service;
    final review = _reviewStatus.review;
    if (service == null || review == null) return;
    _reviewStatus.setMutationLoading(true);
    try {
      await service.deleteReview(movieId: widget.id, reviewId: review.id);
      if (!mounted) return;
      final generation = ++_reviewMutationGeneration;
      _reviewStatus.updateReview(null);
      unawaited(_refreshDetailAfterReview(generation));
    } on DioException catch (error) {
      if (_isAuthError(error)) return;
      rethrow;
    } finally {
      _reviewStatus.setMutationLoading(false);
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
      });
      _reviewStatus.updateReview(detail.review);
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
  void dispose() {
    _magnetsState?.dispose();
    _reviewsState?.dispose();
    _relatedListsState?.dispose();
    super.dispose();
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
    final magnetsState = _magnetsState!;
    final reviewsState = _reviewsState!;
    final relatedListsState = _relatedListsState!;
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
              magnetsState: magnetsState,
              reviewsState: reviewsState,
              relatedListsState: relatedListsState,
              onRetryMagnets: _retryMagnets,
              onRetryRelatedLists: _retryRelatedLists,
              reviewStatus: _reviewStatus,
              onReviewSortChanged: _changeReviewSort,
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
