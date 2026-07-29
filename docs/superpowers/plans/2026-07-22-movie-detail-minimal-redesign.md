# Movie Detail Minimal Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (
> recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the movie-detail body into the reference image's unobstructed vertical section
order while preserving existing data loading and interactions.

**Architecture:** Keep `MovieDetailPage` and `MovieDetailService` unchanged at their public
boundaries. Compose the page from focused private widgets in `movie_detail_screen.dart`, replace the
overlaying draggable sheet with an in-flow auxiliary tab section, and exercise the behavior through
the existing fake API adapter.

**Tech Stack:** Flutter Material 3, Dart, `flutter_test`, existing `FakeAdapter`, existing
`CachedImage`, `ActorCard`, `MovieCard`, and `TagChip` widgets.

## Global Constraints

- Do not add packages or API endpoints.
- Do not modify shared movie cards, actor cards, application theme, or models.
- Keep all user-facing copy as hard-coded Chinese, per `RULES.md`.
- Keep main-detail errors fatal and auxiliary endpoint failures non-fatal.
- The narrow-screen layout must not report overflow exceptions.

---

### Task 1: Add the movie-detail layout regression test

**Files:**

- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`

**Interfaces:**

- Consumes: `MovieDetailPage(id: String)` and `_setupApiClient()`.
- Produces: a regression test that defines the required section order and overlay-free layout.

- [ ] **Step 1: Add representative fake detail and recommendation responses**

Extend the test file with a helper that enqueues a complete detail response containing one tag,
actor, and screenshot, plus `/api/v1/movies/may_also_like` data containing one recommended movie.
Use these exact visible values in assertions: `SSIS-001`, `2026-07-22`, `120分钟`, `测试导演`,
`测试片商`, `测试系列`, `剧情`, `测试演员`, `剧照`, `TA还出演过`, and `你可能也喜欢`.

- [ ] **Step 2: Write the failing reference-layout test**

Add this test shape after the existing auxiliary-failure test:

```dart
testWidgets
('影片详情按参考顺序展示且正文不被常驻抽屉遮挡
'
, (tester) async {
tester.view.physicalSize = const Size(390, 844);
tester.view.devicePixelRatio = 1;
addTearDown(tester.view.resetPhysicalSize);
addTearDown(tester.view.resetDevicePixelRatio);

final adapter = await _setupApiClient();
_enqueueCompleteMovieDetail(adapter);

await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
await tester.pump(const Duration(milliseconds: 100));
await tester.pump(const Duration(milliseconds: 100));

expect(find.byType(DraggableScrollableSheet), findsNothing);
expect(find.text('番号: SSIS-001'), findsOneWidget);
expect(find.text('类别:'), findsOneWidget);
expect(find.text('演员'), findsOneWidget);
expect(find.text('预告片 / 剧照'), findsOneWidget);
expect(tester.takeException(), isNull);

final scrollable = find.byType(CustomScrollView);
await tester.scrollUntilVisible(find.text('你可能也喜欢'), 500,
scrollable: scrollable);
expect(find.text('TA还出演过'), findsOneWidget);
expect(find.text('你可能也喜欢'), findsOneWidget);
expect(tester.takeException(), isNull);
});
```

- [ ] **Step 3: Run the target test and verify RED**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart`

Expected: FAIL because `类别:` and `预告片 / 剧照` are absent and `DraggableScrollableSheet` is
still present.

- [ ] **Step 4: Commit the failing regression test**

```bash
git add test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "test: cover movie detail reference layout"
```

---

### Task 2: Recompose the movie-detail page into non-overlapping sections

**Files:**

- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Test: `test/features/movie_detail/movie_detail_screen_test.dart`

**Interfaces:**

- Consumes: existing `MovieDetail`, `Magnet`, `Review`, and `MovieSummary` state.
- Produces: private `_MovieHero`, `_MovieInfoCard`, `_CategorySection`, `_ActorSection`,
  `_ScreenshotSection`, `_MovieRowSection`, and `_AuxiliaryTabs` widgets.

- [ ] **Step 1: Replace the wide action `Row` with an overflow-safe `Wrap`**

Render the three actions using:

```dart
Wrap
(
spacing: 8,
runSpacing: 8,
children: [
FilledButton(onPressed: () {}, child: const Text('想看')),
FilledButton(onPressed: () {}, child: const Text('看过')),
FilledButton(onPressed: () {}, child: const Text('存入清单'))
,
]
,
)
```

Keep the count text immediately below the actions.

- [ ] **Step 2: Build the ordered sliver sections**

Change the `CustomScrollView` children to this exact semantic order:

```dart
slivers: [
SliverToBoxAdapter
(
child: _MovieHero(detail: d)),
SliverPadding(
padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
sliver: SliverToBoxAdapter(child: _MovieInfoCard(detail: d)),
),
if (d.tags.isNotEmpty)
SliverToBoxAdapter(child: _CategorySection(tags: d.tags)),
if (d.actors.isNotEmpty)
SliverToBoxAdapter(child: _ActorSection(actors: d.actors)),
if (d.screenshots.isNotEmpty)
SliverToBoxAdapter(child: _ScreenshotSection(urls: d.screenshots)),
if (_mayAlsoLike.isNotEmpty)
SliverToBoxAdapter(
child: _MovieRowSection(
title: 'TA还出演过',
movies: _mayAlsoLike,
),
),
if (_mayAlsoLike.isNotEmpty)
SliverToBoxAdapter(
child: _MovieRowSection(
title: '你可能也喜欢',
movies: _mayAlsoLike,
),
),
SliverToBoxAdapter(
child: _AuxiliaryTabs(magnets: _magnets, reviews: _reviews),
),
const SliverToBoxAdapter(child: SizedBox(height: 24)),
]
```

Pass navigation callbacks into actor and movie cards using the existing `/actor/:id` and
`/movie/:id` routes.

- [ ] **Step 3: Implement the focused private widgets**

Use current theme tokens for colors and typography. `_MovieHero` renders a full-width
`AspectRatio(aspectRatio: 1.45)` with `CachedImage(detail.coverUrl, fit: BoxFit.cover)`.
`_MovieInfoCard` uses `Card` plus 16-pixel padding, conditional metadata rows, the overflow-safe
action `Wrap`, and the count text. `_CategorySection` begins with `Text('类别:')` and renders
`TagChip`s in a `Wrap`. `_ActorSection`, `_ScreenshotSection`, and `_MovieRowSection` each render a
padded title and a bounded horizontal `ListView.builder`. The screenshot heading must be
`预告片 / 剧照`.

- [ ] **Step 4: Move auxiliary tabs into normal document flow**

Delete `Scaffold.bottomSheet`. Implement `_AuxiliaryTabs` as a 320-pixel-tall `DefaultTabController`
inside the final sliver. Keep the three existing tab labels and list content, so magnet and review
data remain accessible without covering earlier sections.

- [ ] **Step 5: Format and run the target test for GREEN**

Run:
`dart format lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart`

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart`

Expected: all movie-detail widget tests PASS with no overflow exception.

- [ ] **Step 6: Commit the implementation**

```bash
git add lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "fix: rebuild movie detail layout"
```

---

### Task 3: Verify analysis, regression tests, and Android rendering

**Files:**

- Verify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Verify: `test/features/movie_detail/movie_detail_screen_test.dart`

**Interfaces:**

- Consumes: the completed page and connected `emulator-5554`.
- Produces: analyzer, test, and `adb_tool` evidence for the final handoff.

- [ ] **Step 1: Run focused and full static verification**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart`

Expected: PASS.

Run: `flutter analyze`

Expected: `No issues found!` or no new issue attributable to the changed files.

- [ ] **Step 2: Launch the app on the connected emulator**

Run `flutter run -d emulator-5554` and wait for the application to reach its first frame. Keep the
process alive for ADB inspection.

- [ ] **Step 3: Inspect the rendered detail page with `adb_tool`**

Use `adb_tool` to launch the Jade package, navigate to a movie detail through the visible UI,
capture the top screenshot, scroll through actors and screenshots, then capture the recommendation
sections. Confirm the page has no overlay obscuring the content and no visible overflow stripe.

- [ ] **Step 4: Review the final diff**

Run: `git diff HEAD~2 --check`

Run: `git status --short`

Expected: no whitespace errors; only intentional source/test changes remain beyond the committed
design and plan documents.
