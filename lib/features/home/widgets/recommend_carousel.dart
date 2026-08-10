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

  bool get _shouldAutoPlay =>
      widget.movies.length > 1 &&
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
    if (_tickerModeEnabled == enabled) return;
    _tickerModeEnabled = enabled;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAutoPlay = widget.movies.length > 1;
    return CarouselSlider.builder(
      key: const Key('home-recommend-carousel'),
      carouselController: _controller,
      itemCount: widget.movies.length,
      options: CarouselOptions(
        height: 220,
        viewportFraction: 1,
        enableInfiniteScroll: canAutoPlay,
        autoPlay: canAutoPlay,
        autoPlayInterval: const Duration(seconds: 5),
        autoPlayAnimationDuration: const Duration(milliseconds: 400),
        autoPlayCurve: Curves.easeInOut,
        pauseAutoPlayOnTouch: true,
        enlargeCenterPage: false,
      ),
      itemBuilder: (context, index, realIndex) {
        final movie = widget.movies[index];
        return GestureDetector(
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
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
