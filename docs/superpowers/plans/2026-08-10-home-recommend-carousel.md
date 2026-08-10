# Home Recommendation Carousel Slider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the home “佳片推荐” section to use `carousel_slider 5.1.2` for five-second infinite auto-play with touch, application-lifecycle, and navigation-visibility pause behavior.

**Architecture:** A feature-local `RecommendCarousel` wraps `CarouselSlider.builder`, owns a `CarouselSliderController`, and translates lifecycle or `TickerMode` changes into `startAutoPlay()` and `stopAutoPlay()`. `HomePage` keeps data/error state and detail navigation; the package owns timers, infinite page mapping, touch pause, and animation.

**Tech Stack:** Flutter, Dart, `carousel_slider: ^5.1.2`, `flutter_test`

## Global Constraints

- Query `carousel_slider` API through Context7 before implementation; Context7 library ID is `/serenader2014/flutter_carousel_slider`.
- Pin the compatible constraint to `carousel_slider: ^5.1.2`.
- Auto-advance interval is exactly 5 seconds; animation duration is 400 milliseconds with `Curves.easeInOut`.
- Infinite scroll and auto-play are enabled only when there are at least two movies.
- Touch interaction pauses auto-play and resumes after interaction.
- Application background and disabled `TickerMode` stop auto-play; visibility restoration starts it.
- Keep carousel height `220`, `viewportFraction: 1`, current cover/title UI, and `/movie/:id` navigation.
- Do not retain a custom `Timer`, virtual page index, or direct `PageController`.
- Preserve existing unrelated movie-detail/API-model changes in the original master checkout.

---

## File Structure

- Modify `pubspec.yaml`: add the runtime dependency.
- Modify `pubspec.lock`: lock the resolved `carousel_slider` version.
- Create `lib/features/home/widgets/recommend_carousel.dart`: isolate third-party configuration and visibility control.
- Create `test/features/home/recommend_carousel_test.dart`: verify visible carousel behavior.
- Modify `lib/features/home/screens/home_screen.dart`: replace the inline `PageView`.
- Modify `test/features/home/home_screen_test.dart`: prove real-home integration.

### Task 1: Add dependency and package-owned auto-play

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/features/home/widgets/recommend_carousel.dart`
- Create: `test/features/home/recommend_carousel_test.dart`

**Interfaces:**
- Produces: `RecommendCarousel({Key? key, required List<MovieSummary> movies, required ValueChanged<MovieSummary> onMovieTap})`
- Uses: `CarouselSlider.builder(itemCount:, itemBuilder:, options:, carouselController:)`
- Test selectors: `Key('home-recommend-carousel')` and `Key('home-recommend-card-${movie.id}')`

- [ ] **Step 1: Add the verified dependency**

Run:

```bash
flutter pub add carousel_slider:^5.1.2
```

Expected: `pubspec.yaml` contains `carousel_slider: ^5.1.2`, `pubspec.lock` resolves `5.1.2`, and `flutter pub get` succeeds.

- [ ] **Step 2: Write failing visible-behavior tests**

```dart
// test/features/home/recommend_carousel_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/home/widgets/recommend_carousel.dart';

const movies = [
  MovieSummary(id: 'a', number: 'A-1', title: 'A', coverUrl: ''),
  MovieSummary(id: 'b', number: 'B-1', title: 'B', coverUrl: ''),
  MovieSummary(id: 'c', number: 'C-1', title: 'C', coverUrl: ''),
];

Future<void> pumpCarousel(
  WidgetTester tester, {
  List<MovieSummary> items = movies,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 220,
          child: RecommendCarousel(movies: items, onMovieTap: (_) {}),
        ),
      ),
    ),
  );
}

Future<void> finishAutoPlayAnimation(WidgetTester tester) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> finishManualSwipe(WidgetTester tester) async {
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void expectVisibleTitle(WidgetTester tester, String title) {
  final carouselCenter = tester.getCenter(find.byType(CarouselSlider)).dx;
  final titleCenter = tester.getCenter(find.text(title)).dx;
  expect(titleCenter, closeTo(carouselCenter, 5));
}

void main() {
  testWidgets('佳片推荐由 CarouselSlider 承载', (tester) async {
    await pumpCarousel(tester);

    expect(find.byType(CarouselSlider), findsOneWidget);
  });

  testWidgets('满 5 秒后自动显示下一张推荐', (tester) async {
    await pumpCarousel(tester);
    expectVisibleTitle(tester, 'A');

    await tester.pump(const Duration(milliseconds: 4999));
    expectVisibleTitle(tester, 'A');

    await tester.pump(const Duration(milliseconds: 1));
    await finishAutoPlayAnimation(tester);
    expectVisibleTitle(tester, 'B');
  });

  testWidgets('最后一张之后继续显示第一张', (tester) async {
    await pumpCarousel(tester);

    for (var index = 0; index < movies.length; index++) {
      await tester.pump(const Duration(seconds: 5));
      await finishAutoPlayAnimation(tester);
    }

    expectVisibleTitle(tester, 'A');
  });
}
```

- [ ] **Step 3: Run the tests and verify RED**

Run:

```bash
flutter test test/features/home/recommend_carousel_test.dart
```

Expected: the architecture test fails because the existing rejected implementation uses a custom `PageView` and `Timer`, not `CarouselSlider`.

- [ ] **Step 4: Implement package-owned auto-play**

```dart
// lib/features/home/widgets/recommend_carousel.dart
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

class _RecommendCarouselState extends State<RecommendCarousel> {
  final CarouselSliderController _controller = CarouselSliderController();

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
```

- [ ] **Step 5: Run the focused tests and verify GREEN**

Run:

```bash
flutter test test/features/home/recommend_carousel_test.dart
```

Expected: timed advance and infinite-loop tests pass without custom timer code.

- [ ] **Step 6: Commit dependency and base carousel**

```bash
git add pubspec.yaml pubspec.lock lib/features/home/widgets/recommend_carousel.dart test/features/home/recommend_carousel_test.dart
git commit -m "feat(home): refactor recommendations with carousel slider"
```

### Task 2: Lifecycle, touch, and single-item safety

**Files:**
- Modify: `lib/features/home/widgets/recommend_carousel.dart`
- Modify: `test/features/home/recommend_carousel_test.dart`

**Interfaces:**
- Consumes: `WidgetsBindingObserver`, `TickerMode.of(context)`, and `CarouselSliderController`
- Produces: controller auto-play synchronized with application and navigation visibility

- [ ] **Step 1: Add failing interaction and visibility tests**

Add tests for:

```dart
testWidgets('手动滑动后重新等待完整 5 秒', (tester) async {
  await pumpCarousel(tester);
  final carousel = find.byKey(const Key('home-recommend-carousel'));

  await tester.pump(const Duration(seconds: 4));
  await tester.drag(carousel, const Offset(-600, 0));
  await finishManualSwipe(tester);
  expectVisibleTitle(tester, 'B');

  await tester.pump(const Duration(milliseconds: 4399));
  expectVisibleTitle(tester, 'B');
  await tester.pump(const Duration(milliseconds: 1));
  await finishAutoPlayAnimation(tester);
  expectVisibleTitle(tester, 'C');
});

testWidgets('只有一张推荐时不会自动切换', (tester) async {
  await pumpCarousel(tester, items: [movies.first]);

  await tester.pump(const Duration(seconds: 15));

  expectVisibleTitle(tester, 'A');
});

testWidgets('应用在后台时暂停并在恢复后重新计时', (tester) async {
  await pumpCarousel(tester);
  await tester.pump(const Duration(seconds: 2));
  tester.binding.handleAppLifecycleStateChanged(
    AppLifecycleState.paused,
  );
  await tester.pump();

  await tester.pump(const Duration(seconds: 10));
  await finishAutoPlayAnimation(tester);
  expectVisibleTitle(tester, 'A');

  tester.binding.handleAppLifecycleStateChanged(
    AppLifecycleState.resumed,
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await finishAutoPlayAnimation(tester);
  expectVisibleTitle(tester, 'A');
  await tester.pump(const Duration(milliseconds: 1599));
  expectVisibleTitle(tester, 'A');
  await tester.pump(const Duration(milliseconds: 1));
  await finishAutoPlayAnimation(tester);
  expectVisibleTitle(tester, 'B');
});

testWidgets('TickerMode 关闭时暂停并在恢复后重新计时', (tester) async {
  Widget harness(bool enabled) => MaterialApp(
    home: TickerMode(
      enabled: enabled,
      child: Scaffold(
        body: SizedBox(
          height: 220,
          child: RecommendCarousel(movies: movies, onMovieTap: (_) {}),
        ),
      ),
    ),
  );

  await tester.pumpWidget(harness(true));
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpWidget(harness(false));
  await tester.pump(const Duration(seconds: 10));
  await finishAutoPlayAnimation(tester);
  expectVisibleTitle(tester, 'A');

  await tester.pumpWidget(harness(true));
  await tester.pump(const Duration(seconds: 3));
  await finishAutoPlayAnimation(tester);
  expectVisibleTitle(tester, 'A');
  await tester.pump(const Duration(milliseconds: 1599));
  expectVisibleTitle(tester, 'A');
  await tester.pump(const Duration(milliseconds: 1));
  await finishAutoPlayAnimation(tester);
  expectVisibleTitle(tester, 'B');
});

testWidgets('销毁轮播后没有异步异常', (tester) async {
  await pumpCarousel(tester);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));

  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
flutter test test/features/home/recommend_carousel_test.dart
```

Expected: lifecycle and `TickerMode` tests fail because the thin wrapper does not yet control package auto-play.

- [ ] **Step 3: Add visibility synchronization without a custom timer**

Update `_RecommendCarouselState`:

```dart
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
    final enabled = TickerMode.of(context);
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

  // build() keeps autoPlay based on movie count so controller start/stop
  // remains available after lifecycle changes.
}
```

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
flutter test test/features/home/recommend_carousel_test.dart
```

Expected: all auto-play, touch, single-item, lifecycle, ticker, and disposal tests pass.

- [ ] **Step 5: Commit lifecycle behavior**

```bash
git add lib/features/home/widgets/recommend_carousel.dart test/features/home/recommend_carousel_test.dart
git commit -m "test(home): cover carousel slider lifecycle"
```

### Task 3: Integrate into HomePage

**Files:**
- Modify: `lib/features/home/screens/home_screen.dart`
- Modify: `test/features/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `RecommendCarousel(movies:, onMovieTap:)`
- Preserves: `context.push('/movie/${movie.id}')`, successful-section height `220`, and existing section states

- [ ] **Step 1: Extend the home fixture and add a failing integration test**

Make `_pumpHome` accept a `recommends` fixture and enqueue it under `Endpoints.moviesRecommend`. Add:

```dart
testWidgets('佳片推荐在首页每 5 秒自动显示下一张', (tester) async {
  await _pumpHome(
    tester,
    recommends: const [
      {
        'id': 'recommend-a',
        'number': 'R-1',
        'title': 'Recommend A',
        'cover_url': 'recommend-a.jpg',
      },
      {
        'id': 'recommend-b',
        'number': 'R-2',
        'title': 'Recommend B',
        'cover_url': 'recommend-b.jpg',
      },
    ],
  );

  expect(find.text('Recommend A').hitTestable(), findsOneWidget);
  await tester.pump(const Duration(seconds: 5));
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('Recommend B').hitTestable(), findsOneWidget);
});
```

- [ ] **Step 2: Run the home test and verify RED**

Run:

```bash
flutter test test/features/home/home_screen_test.dart
```

Expected: the integration test fails because `HomePage` still builds its inline finite `PageView`.

- [ ] **Step 3: Replace the inline PageView**

Add:

```dart
import 'package:jade/features/home/widgets/recommend_carousel.dart';
```

Remove the no-longer-used `movie_cover_image.dart` import and replace the successful recommendation body with:

```dart
return SliverToBoxAdapter(
  child: SizedBox(
    height: 220,
    child: RecommendCarousel(
      movies: section.items,
      onMovieTap: (movie) => context.push('/movie/${movie.id}'),
    ),
  ),
);
```

- [ ] **Step 4: Run focused tests and verify GREEN**

Run:

```bash
flutter test test/features/home/recommend_carousel_test.dart test/features/home/home_screen_test.dart
```

Expected: all carousel and existing home loading/error/pagination tests pass.

- [ ] **Step 5: Commit integration**

```bash
git add lib/features/home/screens/home_screen.dart test/features/home/home_screen_test.dart
git commit -m "feat(home): enable recommendation carousel auto-play"
```

### Task 4: Format and full verification

**Files:**
- Verify:
  - `pubspec.yaml`
  - `pubspec.lock`
  - `lib/features/home/widgets/recommend_carousel.dart`
  - `lib/features/home/screens/home_screen.dart`
  - `test/features/home/recommend_carousel_test.dart`
  - `test/features/home/home_screen_test.dart`

- [ ] **Step 1: Format changed Dart files**

```bash
dart format lib/features/home/widgets/recommend_carousel.dart lib/features/home/screens/home_screen.dart test/features/home/recommend_carousel_test.dart test/features/home/home_screen_test.dart
```

- [ ] **Step 2: Run focused tests**

```bash
flutter test test/features/home/recommend_carousel_test.dart test/features/home/home_screen_test.dart
```

- [ ] **Step 3: Run static analysis**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Run complete regression suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Verify dependency and diff hygiene**

```bash
flutter pub deps --style=compact
git diff --check
git status --short
git diff --cached --name-only
```

Expected: `carousel_slider 5.1.2` is present; no whitespace errors; only approved feature and dependency files belong to this branch.
