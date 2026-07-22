# 影片详情 Tabs 重排 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将影片详情页内容组织进封面下方的四个无 Card Tabs，并压缩操作按钮与详情类别样式。

**Architecture:** 使用 `DefaultTabController + NestedScrollView + pinned SliverPersistentHeader + TabBarView` 协调封面外层滚动和各 Tab 内层滚动。新增私有 `_BasicInfoTab` 组合现有信息卡、类别、演员、剧照和推荐模块；共享 `TagChip` 增加默认关闭的 compact 参数，避免影响其他页面。

**Tech Stack:** Flutter、Dart、Material 3、flutter_test

## Global Constraints

- Tabs 顺序固定为“基本信息”“磁链下载”“短评”“相关清单”。
- Tabs 必须紧接封面、可吸顶且没有 Card 祖先。
- 基本信息包含信息卡、类别、演员、剧照、“TA还出演过”和“你可能也喜欢”。
- 封面随外层滚动离开视口，Tab 内容使用内层纵向滚动。
- 操作按钮最小高度 32、横向 padding 12、`VisualDensity.compact`、`labelMedium`。
- 详情类别使用 `bodyMedium` 加粗标题，标签使用 compact、shrinkWrap、`labelSmall`，间距为 4。
- 仅详情页启用紧凑类别，不改变其他 TagChip 默认样式。
- 不新增依赖，不修改接口、数据模型、操作按钮业务逻辑、相关清单数据源或图片模糊功能。

---

### Task 1: 为 TagChip 增加可选紧凑样式

**Files:**
- Modify: `lib/core/widgets/tag_chip.dart`
- Create: `test/core/widgets/tag_chip_test.dart`

**Interfaces:**
- Consumes: Material `ActionChip`。
- Produces: `TagChip(..., bool compact = false)`；compact 为 true 时设置紧凑视觉密度、shrinkWrap 点击目标和 `labelSmall` 字体。

- [ ] **Step 1: 写默认样式不变和紧凑样式失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/tag_chip.dart';

void main() {
  testWidgets('TagChip 默认不强制紧凑样式', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TagChip(label: '剧情'))),
    );

    final chip = tester.widget<ActionChip>(find.byType(ActionChip));
    expect(chip.visualDensity, isNull);
    expect(chip.materialTapTargetSize, isNull);
    expect(chip.labelStyle, isNull);
  });

  testWidgets('TagChip compact 使用紧凑密度和小号文字', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TagChip(label: '剧情', compact: true)),
      ),
    );

    final context = tester.element(find.byType(ActionChip));
    final chip = tester.widget<ActionChip>(find.byType(ActionChip));
    expect(chip.visualDensity, VisualDensity.compact);
    expect(chip.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
    expect(chip.labelStyle, Theme.of(context).textTheme.labelSmall);
  });
}
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/core/widgets/tag_chip_test.dart`

Expected: FAIL，提示 `compact` 参数未定义。

- [ ] **Step 3: 实现向后兼容的 compact 参数**

```dart
import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      visualDensity: compact ? VisualDensity.compact : null,
      materialTapTargetSize: compact
          ? MaterialTapTargetSize.shrinkWrap
          : null,
      labelStyle: compact ? Theme.of(context).textTheme.labelSmall : null,
    );
  }
}
```

- [ ] **Step 4: 运行测试并确认 GREEN**

Run: `flutter test test/core/widgets/tag_chip_test.dart`

Expected: PASS，2 项测试全部通过。

- [ ] **Step 5: 提交 TagChip 紧凑能力**

```bash
git add lib/core/widgets/tag_chip.dart test/core/widgets/tag_chip_test.dart
git commit -m "feat: add compact tag chip style"
```

### Task 2: 压缩详情操作按钮和类别

**Files:**
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`

**Interfaces:**
- Consumes: `TagChip(compact: true)`。
- Produces: key 为 `movie-detail-actions` 的紧凑按钮 Wrap；详情类别全部使用紧凑 TagChip。

- [ ] **Step 1: 在详情测试中增加紧凑样式失败断言**

在完整详情测试首次 pump 后增加：

```dart
final actions = find.byKey(const Key('movie-detail-actions'));
expect(actions, findsOneWidget);
expect(find.descendant(of: actions, matching: find.byType(FilledButton)), findsNWidgets(3));

for (final button in tester.widgetList<FilledButton>(
  find.descendant(of: actions, matching: find.byType(FilledButton)),
)) {
  expect(button.style?.minimumSize?.resolve({}), const Size(0, 32));
  expect(button.style?.visualDensity, VisualDensity.compact);
  expect(
    button.style?.padding?.resolve({}),
    const EdgeInsets.symmetric(horizontal: 12),
  );
}

final categoryChip = tester.widget<TagChip>(
  find.descendant(
    of: find.byKey(const Key('movie-detail-categories')),
    matching: find.byType(TagChip),
  ).first,
);
expect(categoryChip.compact, isTrue);
```

并在测试文件导入：

```dart
import 'package:jade/core/widgets/tag_chip.dart';
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart`

Expected: FAIL，找不到 `movie-detail-actions` 或 `movie-detail-categories`。

- [ ] **Step 3: 实现紧凑操作按钮**

在 `_MovieInfoCard.build` 中创建并复用按钮样式：

```dart
final actionStyle = FilledButton.styleFrom(
  minimumSize: const Size(0, 32),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  visualDensity: VisualDensity.compact,
  textStyle: Theme.of(context).textTheme.labelMedium,
);
```

把现有 Wrap 替换为：

```dart
Wrap(
  key: const Key('movie-detail-actions'),
  spacing: 8,
  runSpacing: 6,
  children: [
    FilledButton(
      style: actionStyle,
      onPressed: () {},
      child: const Text('想看'),
    ),
    FilledButton(
      style: actionStyle,
      onPressed: () {},
      child: const Text('看过'),
    ),
    FilledButton(
      style: actionStyle,
      onPressed: () {},
      child: const Text('存入清单'),
    ),
  ],
)
```

- [ ] **Step 4: 实现详情类别紧凑样式**

将 `_CategorySection.build` 替换为：

```dart
@override
Widget build(BuildContext context) {
  return Padding(
    key: const Key('movie-detail-categories'),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '类别:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final tag in tags) TagChip(label: tag, compact: true),
            ],
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 5: 运行测试并确认 GREEN**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart test/core/widgets/tag_chip_test.dart`

Expected: PASS，详情按钮和类别紧凑契约通过，TagChip 默认样式仍不变。

- [ ] **Step 6: 提交详情紧凑样式**

```bash
git add lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "style: compact movie detail actions and categories"
```

### Task 3: 将详情内容重排进封面下方四个 Tabs

**Files:**
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`

**Interfaces:**
- Consumes: 现有 `_MovieHero`、`_MovieInfoCard`、`_CategorySection`、`_ActorSection`、`_ScreenshotSection`、`_MovieRowSection`、`_MagnetList`、`_ReviewList`。
- Produces: `_BasicInfoTab`、`_MovieDetailTabs`、`_MovieDetailTabHeaderDelegate`，以及 key 为 `movie-detail-tab-bar` 的四项 TabBar。

- [ ] **Step 1: 写结构、内容和 Tab 切换失败测试**

把完整详情测试的核心断言调整为：

```dart
expect(find.byType(NestedScrollView), findsOneWidget);
final pinnedHeader = tester.widget<SliverPersistentHeader>(
  find.byType(SliverPersistentHeader),
);
expect(pinnedHeader.pinned, isTrue);

const tabLabels = ['基本信息', '磁链下载', '短评', '相关清单'];
for (final label in tabLabels) {
  expect(find.text(label), findsOneWidget);
}

final tabBar = find.byKey(const Key('movie-detail-tab-bar'));
expect(tabBar, findsOneWidget);
expect(find.ancestor(of: tabBar, matching: find.byType(Card)), findsNothing);
expect(
  tester.getTopLeft(tabBar).dy,
  greaterThan(tester.getTopLeft(find.byType(MovieCoverImage)).dy),
);

expect(find.text('番号: SSIS-001'), findsOneWidget);
expect(find.text('类别:'), findsOneWidget);
expect(tester.takeException(), isNull);

final innerScrollable = find
    .descendant(
      of: find.byType(TabBarView),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            widget.axisDirection == AxisDirection.down,
      ),
    )
    .first;
await tester.scrollUntilVisible(
  find.text('演员'),
  300,
  scrollable: innerScrollable,
);
expect(find.text('演员'), findsOneWidget);

await tester.scrollUntilVisible(
  find.text('预告片 / 剧照'),
  300,
  scrollable: innerScrollable,
);
expect(find.byType(MovieScreenshotImage), findsOneWidget);

await tester.scrollUntilVisible(
  find.text('TA还出演过'),
  500,
  scrollable: innerScrollable,
);
expect(find.text('TA还出演过'), findsOneWidget);

await tester.scrollUntilVisible(
  find.text('你可能也喜欢'),
  500,
  scrollable: innerScrollable,
);
expect(find.text('你可能也喜欢'), findsOneWidget);
expect(tester.takeException(), isNull);

await tester.tap(find.text('磁链下载'));
await tester.pumpAndSettle();
expect(find.text('暂无磁链'), findsOneWidget);

await tester.tap(find.text('短评'));
await tester.pumpAndSettle();
expect(find.text('暂无短评'), findsOneWidget);

await tester.tap(find.text('相关清单'));
await tester.pumpAndSettle();
expect(find.text('相关清单'), findsNWidgets(2));
```

测试文件增加：

```dart
import 'package:jade/core/widgets/movie_cover_image.dart';
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart`

Expected: FAIL，当前页面没有 NestedScrollView、基本信息 Tab 或 pinned header，且 Tabs 仍位于 Card 中。

- [ ] **Step 3: 用 MovieDetailTabs 替换 CustomScrollView 内容编排**

将成功状态 Scaffold 的 body 替换为：

```dart
body: DefaultTabController(
  length: 4,
  child: _MovieDetailTabs(
    detail: detail,
    magnets: _magnets,
    reviews: _reviews,
    mayAlsoLike: _mayAlsoLike,
    onActorTap: (actor) => context.push('/actor/${actor.id}'),
    onMovieTap: (movie) => context.push('/movie/${movie.id}'),
  ),
),
```

- [ ] **Step 4: 新增基本信息组合组件**

```dart
class _BasicInfoTab extends StatelessWidget {
  const _BasicInfoTab({
    required this.detail,
    required this.mayAlsoLike,
    required this.onActorTap,
    required this.onMovieTap,
  });

  final MovieDetail detail;
  final List<MovieSummary> mayAlsoLike;
  final ValueChanged<ActorSummary> onActorTap;
  final ValueChanged<MovieSummary> onMovieTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _MovieInfoCard(detail: detail),
        ),
        if (detail.tags.isNotEmpty) _CategorySection(tags: detail.tags),
        if (detail.actors.isNotEmpty)
          _ActorSection(actors: detail.actors, onActorTap: onActorTap),
        if (detail.screenshots.isNotEmpty)
          _ScreenshotSection(urls: detail.screenshots),
        if (mayAlsoLike.isNotEmpty)
          _MovieRowSection(
            title: 'TA还出演过',
            movies: mayAlsoLike,
            onMovieTap: onMovieTap,
          ),
        if (mayAlsoLike.isNotEmpty)
          _MovieRowSection(
            title: '你可能也喜欢',
            movies: mayAlsoLike,
            onMovieTap: onMovieTap,
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: 新增 NestedScrollView、四个 Tabs 和吸顶 delegate**

```dart
class _MovieDetailTabs extends StatelessWidget {
  const _MovieDetailTabs({
    required this.detail,
    required this.magnets,
    required this.reviews,
    required this.mayAlsoLike,
    required this.onActorTap,
    required this.onMovieTap,
  });

  final MovieDetail detail;
  final List<Magnet> magnets;
  final List<Review> reviews;
  final List<MovieSummary> mayAlsoLike;
  final ValueChanged<ActorSummary> onActorTap;
  final ValueChanged<MovieSummary> onMovieTap;

  @override
  Widget build(BuildContext context) {
    const tabBar = TabBar(
      key: Key('movie-detail-tab-bar'),
      tabs: [
        Tab(text: '基本信息'),
        Tab(text: '磁链下载'),
        Tab(text: '短评'),
        Tab(text: '相关清单'),
      ],
    );
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(child: _MovieHero(detail: detail)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _MovieDetailTabHeaderDelegate(
            tabBar: tabBar,
            backgroundColor: Theme.of(context).colorScheme.surface,
            dividerColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ],
      body: TabBarView(
        children: [
          _BasicInfoTab(
            detail: detail,
            mayAlsoLike: mayAlsoLike,
            onActorTap: onActorTap,
            onMovieTap: onMovieTap,
          ),
          _MagnetList(magnets: magnets),
          _ReviewList(reviews: reviews),
          const Center(child: Text('相关清单')),
        ],
      ),
    );
  }
}

class _MovieDetailTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _MovieDetailTabHeaderDelegate({
    required this.tabBar,
    required this.backgroundColor,
    required this.dividerColor,
  });

  final TabBar tabBar;
  final Color backgroundColor;
  final Color dividerColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_MovieDetailTabHeaderDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor ||
        dividerColor != oldDelegate.dividerColor;
  }
}
```

删除不再使用的 `_AuxiliaryTabs`，保留 `_MagnetList` 和 `_ReviewList`。

- [ ] **Step 6: 运行详情测试并确认 GREEN**

Run: `flutter test test/features/movie_detail/movie_detail_screen_test.dart`

Expected: PASS，四 Tabs、基本信息完整内容、吸顶结构、无 Card 外框和 Tab 切换全部通过。

- [ ] **Step 7: 提交 Tabs 重排**

```bash
git add lib/features/movie_detail/screens/movie_detail_screen.dart test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "feat: reorganize movie detail tabs"
```

### Task 4: 格式化、全量回归与设备验收

**Files:**
- Verify: `lib/core/widgets/tag_chip.dart`
- Verify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Verify: `test/core/widgets/tag_chip_test.dart`
- Verify: `test/features/movie_detail/movie_detail_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 1-3 的完整实现。
- Produces: 格式化、自动化验证和 Android 设备验收证据。

- [ ] **Step 1: 格式化修改文件**

Run:

```bash
dart format lib/core/widgets/tag_chip.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/widgets/tag_chip_test.dart test/features/movie_detail/movie_detail_screen_test.dart
```

Expected: formatter exits 0。

- [ ] **Step 2: 运行相关测试**

Run:

```bash
flutter test test/core/widgets/tag_chip_test.dart test/features/movie_detail/movie_detail_screen_test.dart
```

Expected: 所有相关测试通过。

- [ ] **Step 3: 运行完整测试和静态分析**

Run: `flutter test`

Expected: `All tests passed!`

Run: `dart analyze`

Expected: `No issues found!`

- [ ] **Step 4: 安装并使用 adb_tool 验收**

Run: `flutter run -d emulator-5554 --debug --no-resident`

使用 adb_tool 检查：

1. Tabs 紧接封面且没有 Card 外框。
2. 向上滚动后封面离开视口，Tabs 停留在 AppBar 下方。
3. 基本信息内依次可见信息卡、紧凑类别、演员、剧照和两个推荐区块。
4. 三个操作按钮更紧凑且没有换行溢出。
5. 磁链下载、短评、相关清单 Tab 均可切换并展示正确内容或空状态。
6. adb_tool 日志查询不存在 `RenderFlex`、`overflowed`、`FATAL EXCEPTION` 或 `Unhandled Exception`。

Expected: 六项设备检查全部满足。

- [ ] **Step 5: 检查并提交格式化收尾**

Run: `git diff --check && git status --short`

Expected: `git diff --check` 无输出；若 dart format 产生修改，提交：

```bash
git add lib/core/widgets/tag_chip.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/widgets/tag_chip_test.dart test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "style: format movie detail tab layout"
```
