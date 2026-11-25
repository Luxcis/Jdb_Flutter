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

  bool get _canAutoPlay => widget.movies.length > 1;

  /// 是否允许自动轮播（不含生命周期/TickerMode，这两项由有效状态控制）。
  bool get _autoPlayEnabled => _canAutoPlay && !_reduceMotion;

  /// 当前是否应自动轮播：切到其他 tab 时 GoRouter 的 IndexedStack 会关闭
  /// TickerMode，自动轮播随之暂停；切回或应用恢复前台后重新计时。
  bool get _shouldAutoPlay =>
      _autoPlayEnabled &&
      _lifecycleState == AppLifecycleState.resumed &&
      _tickerModeEnabled;

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
    if (_lifecycleState == state) return;
    _lifecycleState = state;
    // 生命周期变化不一定触发父级重建；显式刷新以同步 autoPlay 选项。
    if (mounted) setState(() {});
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CarouselSlider.builder(
      key: const Key('home-recommend-carousel'),
      carouselController: _controller,
      itemCount: widget.movies.length,
      options: CarouselOptions(
        height: 220,
        viewportFraction: 1,
        enableInfiniteScroll: _canAutoPlay,
        // 直接使用当前有效状态：离屏分支重建时 carousel_slider 会按该值
        // 重建计时器，用“允许播放”代替会让切走后的轮播继续滚动。
        autoPlay: _shouldAutoPlay,
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
    );
  }
}
