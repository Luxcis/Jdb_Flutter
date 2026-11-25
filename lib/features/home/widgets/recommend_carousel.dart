import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';

class RecommendCarousel extends StatefulWidget {
  const RecommendCarousel({
    super.key,
    required this.movies,
    required this.onMovieTap,
  });

  /// 暂停/播放自动轮播的控制按钮（便于测试定位）。
  static const autoPlayToggleKey = Key('home-recommend-autoplay-toggle');

  final List<MovieSummary> movies;
  final ValueChanged<MovieSummary> onMovieTap;

  @override
  State<RecommendCarousel> createState() => _RecommendCarouselState();
}

class _RecommendCarouselState extends State<RecommendCarousel>
    with WidgetsBindingObserver {
  final CarouselSliderController _controller = CarouselSliderController();
  AppLifecycleState _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  bool _tickerModeEnabled = true;

  /// 系统开启“减少动态效果”时不自动轮播。
  bool _reduceMotion = false;

  /// 用户通过角标按钮暂停自动轮播。
  bool _userPaused = false;

  bool get _canAutoPlay => widget.movies.length > 1;

  /// 是否允许自动轮播（不含生命周期/TickerMode，这两项由控制器同步）。
  ///
  /// 系统“减少动态效果”是硬性关闭：只要该设置开启就不自动切换，
  /// 角标按钮仍会展示但禁用，并用 tooltip 说明原因。
  bool get _autoPlayEnabled => _canAutoPlay && !_reduceMotion && !_userPaused;

  bool get _shouldAutoPlay =>
      _autoPlayEnabled &&
      _lifecycleState == AppLifecycleState.resumed &&
      _tickerModeEnabled;

  bool get _showAutoPlayToggle => _canAutoPlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncAutoPlay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_tickerModeEnabled == enabled && _reduceMotion == reduceMotion) return;
    _tickerModeEnabled = enabled;
    _reduceMotion = reduceMotion;
    _syncAutoPlay();
  }

  @override
  void didUpdateWidget(covariant RecommendCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies.length != widget.movies.length) _syncAutoPlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _syncAutoPlay();
  }

  void _syncAutoPlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _shouldAutoPlay
          ? _controller.startAutoPlay()
          : _controller.stopAutoPlay();
    });
  }

  void _toggleAutoPlay() {
    setState(() => _userPaused = !_userPaused);
    _syncAutoPlay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CarouselSlider.builder(
          key: const Key('home-recommend-carousel'),
          carouselController: _controller,
          itemCount: widget.movies.length,
          options: CarouselOptions(
            height: 220,
            viewportFraction: 1,
            enableInfiniteScroll: _canAutoPlay,
            // autoPlay 只表达“是否允许自动切换”；后台/TickerMode
            // 由 startAutoPlay/stopAutoPlay 控制，避免旧 options 残留。
            autoPlay: _autoPlayEnabled,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayAnimationDuration: const Duration(milliseconds: 400),
            autoPlayCurve: Curves.easeInOut,
            pauseAutoPlayOnTouch: true,
            enlargeCenterPage: false,
          ),
          itemBuilder: (context, index, realIndex) {
            final movie = widget.movies[index];
            return Semantics(
              button: true,
              label: movie.title,
              child: GestureDetector(
                key: Key('home-recommend-card-${movie.id}'),
                onTap: () => widget.onMovieTap(movie),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MovieCoverImage(
                      movie.coverUrl,
                      variant: MovieImageVariant.cover,
                      semanticLabel: movie.title,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          movie.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_showAutoPlayToggle)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                key: RecommendCarousel.autoPlayToggleKey,
                // 减少动效下轮播不会自动切换，按钮保留但禁用，
                // 并通过 tooltip 说明原因，避免用户误以为功能失效。
                tooltip: _reduceMotion
                    ? '系统已开启减少动态效果'
                    : (_userPaused ? '播放轮播' : '暂停轮播'),
                onPressed: _reduceMotion ? null : _toggleAutoPlay,
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                color: Colors.white,
                disabledColor: Colors.white70,
                icon: Icon(_autoPlayEnabled ? Icons.pause : Icons.play_arrow),
              ),
            ),
          ),
      ],
    );
  }
}
