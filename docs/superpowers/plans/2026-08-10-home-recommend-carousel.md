# Home Recommendation Carousel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the home “佳片推荐” PageView automatically advance every 5 seconds and loop continuously while preserving manual swiping, lifecycle safety, and existing navigation.

**Architecture:** Move the successful recommendation UI into a feature-local `RecommendCarousel` stateful widget. It owns only ephemeral carousel state (`PageController`, one-shot `Timer`, lifecycle and ticker visibility), maps a large virtual page range to the real movie list with modulo, and delegates movie taps back to `HomePage`.

**Tech Stack:** Flutter, Dart `Timer`, `PageView.builder`, `WidgetsBindingObserver`, `TickerMode`, `flutter_test`

## Global Constraints

- Auto-advance interval is exactly 5 seconds.
- The last movie continues forward to the first movie without a reverse rewind animation.
- A completed manual swipe restarts a full 5-second interval.
- Auto-play pauses while the application or home navigation branch is not visible and restarts on visibility.
- Zero movies keep the existing `EmptyState`; one movie never starts an auto-play timer.
- Existing carousel height, cover rendering, title overlay, and `/movie/:id` navigation remain unchanged.
- Do not add dependencies or modify recommendation API behavior.
- Preserve and do not stage the existing unrelated movie-detail/API-model worktree changes.

---

## File Structure

- Create `lib/features/home/widgets/recommend_carousel.dart`: owns recommendation rendering and all transient auto-play state.
- Create `test/features/home/recommend_carousel_test.dart`: verifies timing, modulo looping, gestures, lifecycle, ticker visibility, single-item behavior, and disposal.
- Modify `lib/features/home/screens/home_screen.dart`: replaces the inline finite `PageView` with `RecommendCarousel` and keeps the existing route callback.
- Modify `test/features/home/home_screen_test.dart`: proves the real home recommendation section is wired to the auto-playing carousel.

### Task 1: Continuous timed carousel

**Files:**
- Create: `lib/features/home/widgets/recommend_carousel.dart`
- Create: `test/features/home/recommend_carousel_test.dart`

**Interfaces:**
- Consumes: `List<MovieSummary>` and `ValueChanged<MovieSummary> onMovieTap`
- Produces: `RecommendCarousel({Key? key, required List<MovieSummary> movies, required ValueChanged<MovieSummary> onMovieTap})`
- Test selector: `Key('home-recommend-carousel')`
- Visible item selector: `Key('home-recommend-card-${movie.id}')`

- [ ] **Step 1: Write failing tests for timed advance and forward looping**

```dart
// test/features/home/recommend_carousel_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

PageController carouselController(WidgetTester tester) {
  return tester
      .widget<PageView>(
        find.byKey(const Key('home-recommend-carousel')),
      )
      .controller!;
}

testWidgets('满 5 秒后自动向下一张推荐前进', (tester) async {
  await pumpCarousel(tester);
  final controller = carouselController(tester);
  final firstPage = controller.page!;

  await tester.pump(const Duration(milliseconds: 4999));
  expect(controller.page, firstPage);

  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 400));
  expect(controller.page, firstPage + 1);
});

testWidgets('最后一张之后继续向前显示第一张', (tester) async {
  await pumpCarousel(tester);
  final carousel = find.byKey(const Key('home-recommend-carousel'));

  for (var index = 0; index < movies.length; index++) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
  }

  expect(
    find
        .descendant(
          of: carousel,
          matching: find.byKey(const Key('home-recommend-card-a')),
        )
        .hitTestable(),
    findsOneWidget,
  );
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
flutter test test/features/home/recommend_carousel_test.dart
```

Expected: compilation fails because `recommend_carousel.dart` and `RecommendCarousel` do not exist.

- [ ] **Step 3: Implement the minimal virtual PageView and one-shot timer**

```dart
// lib/features/home/widgets/recommend_carousel.dart
import 'dart:async';

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
  static const _autoPlayInterval = Duration(seconds: 5);
  static const _animationDuration = Duration(milliseconds: 400);
  static const _virtualPageBase = 10000;

  late final PageController _pageController;
  Timer? _timer;
  late int _currentPage;

  int _initialPageFor(int movieCount) =>
      movieCount < 2
          ? 0
          : _virtualPageBase - (_virtualPageBase % movieCount);

  @override
  void initState() {
    super.initState();
    _currentPage = _initialPageFor(widget.movies.length);
    _pageController = PageController(initialPage: _currentPage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleNext());
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!mounted || widget.movies.length < 2) return;
    _timer = Timer(_autoPlayInterval, _advance);
  }

  void _advance() {
    if (!mounted || !_pageController.hasClients) return;
    _pageController.animateToPage(
      _currentPage + 1,
      duration: _animationDuration,
      curve: Curves.easeInOut,
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _timer?.cancel();
    } else if (notification is ScrollEndNotification) {
      _scheduleNext();
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: PageView.builder(
        key: const Key('home-recommend-carousel'),
        controller: _pageController,
        itemCount: widget.movies.length < 2 ? widget.movies.length : null,
        onPageChanged: (page) => _currentPage = page,
        itemBuilder: (context, virtualIndex) {
          final movie = widget.movies[virtualIndex % widget.movies.length];
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
      ),
    );
  }
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```bash
flutter test test/features/home/recommend_carousel_test.dart
```

Expected: both timed advance and loop tests pass with no pending-timer exception.

- [ ] **Step 5: Commit the isolated component**

```bash
git add lib/features/home/widgets/recommend_carousel.dart test/features/home/recommend_carousel_test.dart
git commit -m "feat(home): add automatic recommendation carousel"
```

### Task 2: Interaction and visibility safety

**Files:**
- Modify: `lib/features/home/widgets/recommend_carousel.dart`
- Modify: `test/features/home/recommend_carousel_test.dart`

**Interfaces:**
- Consumes: Flutter application lifecycle and inherited `TickerMode`
- Produces: auto-play that is active only when `AppLifecycleState.resumed` and `TickerMode.of(context)` are both active

- [ ] **Step 1: Add failing tests for manual reset, one item, app lifecycle, ticker visibility, and disposal**

```dart
// Append inside main() in test/features/home/recommend_carousel_test.dart
testWidgets('手动滑动结束后重新等待完整 5 秒', (tester) async {
  await pumpCarousel(tester);
  final carousel = find.byKey(const Key('home-recommend-carousel'));
  final controller = carouselController(tester);

  await tester.pump(const Duration(seconds: 4));
  await tester.drag(carousel, const Offset(-300, 0));
  await tester.pumpAndSettle();
  final manualPage = controller.page!;

  await tester.pump(const Duration(milliseconds: 4999));
  expect(controller.page, manualPage);
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 400));
  expect(controller.page, manualPage + 1);
});

testWidgets('只有一张推荐时不会自动切换', (tester) async {
  await pumpCarousel(tester, items: [movies.first]);
  final controller = carouselController(tester);

  await tester.pump(const Duration(seconds: 15));

  expect(controller.page, 0);
});

testWidgets('应用在后台时暂停并在恢复后重新计时', (tester) async {
  await pumpCarousel(tester);
  final controller = carouselController(tester);
  final page = controller.page!;

  await tester.binding.handleAppLifecycleStateChanged(
    AppLifecycleState.paused,
  );
  await tester.pump(const Duration(seconds: 10));
  expect(controller.page, page);

  await tester.binding.handleAppLifecycleStateChanged(
    AppLifecycleState.resumed,
  );
  await tester.pump(const Duration(milliseconds: 4999));
  expect(controller.page, page);
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 400));
  expect(controller.page, page + 1);
});

testWidgets('TickerMode 关闭时暂停并在重新可见后计时', (tester) async {
  Widget buildHarness(bool enabled) => MaterialApp(
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

  await tester.pumpWidget(buildHarness(true));
  final controller = carouselController(tester);
  final page = controller.page!;

  await tester.pumpWidget(buildHarness(false));
  await tester.pump(const Duration(seconds: 10));
  expect(controller.page, page);

  await tester.pumpWidget(buildHarness(true));
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 400));
  expect(controller.page, page + 1);
});

testWidgets('销毁后推进时钟不会留下计时器异常', (tester) async {
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

Expected: lifecycle and ticker visibility tests fail because the timer still advances while hidden; timing-reset assertions may reveal duplicate scheduling.

- [ ] **Step 3: Add lifecycle, ticker visibility, and data-update synchronization**

Update the state class to implement `WidgetsBindingObserver`, track visibility, and centralize timer eligibility:

```dart
class _RecommendCarouselState extends State<RecommendCarousel>
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _tickerModeEnabled = true;

  bool get _canAutoPlay =>
      mounted &&
      widget.movies.length > 1 &&
      _lifecycleState == AppLifecycleState.resumed &&
      _tickerModeEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPage = _initialPageFor(widget.movies.length);
    _pageController = PageController(initialPage: _currentPage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleNext());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.of(context);
    if (_tickerModeEnabled == enabled) return;
    _tickerModeEnabled = enabled;
    enabled ? _scheduleNext() : _cancelTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    state == AppLifecycleState.resumed ? _scheduleNext() : _cancelTimer();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleNext() {
    _cancelTimer();
    if (!_canAutoPlay) return;
    _timer = Timer(_autoPlayInterval, _advance);
  }

  void _advance() {
    _timer = null;
    if (!_canAutoPlay || !_pageController.hasClients) return;
    _pageController.animateToPage(
      _currentPage + 1,
      duration: _animationDuration,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(covariant RecommendCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.movies.map((movie) => movie.id).toList();
    final newIds = widget.movies.map((movie) => movie.id).toList();
    if (listEquals(oldIds, newIds)) return;
    _currentPage = _initialPageFor(widget.movies.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(_currentPage);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
    _pageController.dispose();
    super.dispose();
  }
}
```

Use `_cancelTimer()` for manual `ScrollStartNotification`, and schedule only from `ScrollEndNotification`, lifecycle resume, ticker resume, initial post-frame setup, or a movie-list change.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
flutter test test/features/home/recommend_carousel_test.dart
```

Expected: all carousel tests pass without framework exceptions or pending timers.

- [ ] **Step 5: Commit interaction and lifecycle behavior**

```bash
git add lib/features/home/widgets/recommend_carousel.dart test/features/home/recommend_carousel_test.dart
git commit -m "test(home): cover carousel interaction and lifecycle"
```

### Task 3: Integrate carousel into the real home screen

**Files:**
- Modify: `lib/features/home/screens/home_screen.dart`
- Modify: `test/features/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `RecommendCarousel(movies:, onMovieTap:)`
- Preserves: `context.push('/movie/${movie.id}')`
- Preserves: recommendation success container height of `220`

- [ ] **Step 1: Make the home test use three recommendations and add a failing auto-play assertion**

Extend `_pumpHome` with an optional recommendation fixture:

```dart
Future<FakeAdapter> _pumpHome(
  WidgetTester tester, {
  Duration responseDelay = Duration.zero,
  List<Map<String, dynamic>>? latestBodies,
  List<Map<String, dynamic>> recommends = const [
    {
      'id': 'recommend-a',
      'number': 'R-1',
      'title': 'Recommend A',
      'cover_url': 'recommend-a.jpg',
    },
  ],
  bool settle = true,
}) async {
  // Existing setup remains unchanged.
  adapter.enqueue(Endpoints.moviesRecommend, {
    'success': 1,
    'data': {'movies': recommends},
  });
  // Existing latest fixtures and pump logic remain unchanged.
}
```

Add the integration test:

```dart
testWidgets('佳片推荐在首页每 5 秒自动前进', (tester) async {
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
  final pageView = find.byKey(const Key('home-recommend-carousel'));
  final controller = tester.widget<PageView>(pageView).controller!;
  final firstPage = controller.page!;

  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 400));

  expect(controller.page, firstPage + 1);
});
```

- [ ] **Step 2: Run the home test and verify RED**

Run:

```bash
flutter test test/features/home/home_screen_test.dart
```

Expected: the new key is absent because `HomePage` still builds the old inline finite `PageView`.

- [ ] **Step 3: Replace the inline PageView with RecommendCarousel**

Update imports:

```dart
import 'package:jade/features/home/widgets/recommend_carousel.dart';
```

Remove the now-unused `movie_cover_image.dart` import, then replace only the successful recommendation body:

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

- [ ] **Step 4: Run carousel and home tests and verify GREEN**

Run:

```bash
flutter test test/features/home/recommend_carousel_test.dart test/features/home/home_screen_test.dart
```

Expected: all carousel and existing home loading/error/pagination tests pass.

- [ ] **Step 5: Commit the integration**

```bash
git add lib/features/home/screens/home_screen.dart test/features/home/home_screen_test.dart
git commit -m "feat(home): enable recommendation auto-play"
```

### Task 4: Format and full verification

**Files:**
- Verify only:
  - `lib/features/home/widgets/recommend_carousel.dart`
  - `lib/features/home/screens/home_screen.dart`
  - `test/features/home/recommend_carousel_test.dart`
  - `test/features/home/home_screen_test.dart`

**Interfaces:**
- Produces: formatted, analyzed, regression-tested implementation with no unrelated staged files

- [ ] **Step 1: Format only the changed Dart files**

Run:

```bash
dart format lib/features/home/widgets/recommend_carousel.dart lib/features/home/screens/home_screen.dart test/features/home/recommend_carousel_test.dart test/features/home/home_screen_test.dart
```

Expected: formatter completes successfully.

- [ ] **Step 2: Run focused tests after formatting**

Run:

```bash
flutter test test/features/home/recommend_carousel_test.dart test/features/home/home_screen_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 3: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Run the full regression suite**

Run:

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Check diff hygiene and staging scope**

Run:

```bash
git diff --check
git status --short
git diff --cached --name-only
```

Expected: no whitespace errors; only carousel/home files belong to this feature; existing unrelated movie-detail/API-model modifications remain unstaged and unchanged.

- [ ] **Step 6: Commit formatting changes only if formatting changed tracked feature files**

```bash
git add lib/features/home/widgets/recommend_carousel.dart lib/features/home/screens/home_screen.dart test/features/home/recommend_carousel_test.dart test/features/home/home_screen_test.dart
git commit -m "style(home): format recommendation carousel"
```

If `git diff` shows no formatting-only changes, skip this commit.
