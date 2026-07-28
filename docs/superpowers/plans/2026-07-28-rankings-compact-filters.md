# Rankings Compact Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将排行榜各筛选控件统一为紧凑胶囊样式，让日/周/月榜撑满可用宽度，并把 Top250 筛选抽屉固定为约三分之二屏高且禁止上拉扩展。

**Architecture:** 扩展共享 `SortSegmented<T>`，以可选参数提供紧凑和横向撑满能力，默认行为保持不变；排行榜页面组合该能力实现看热播双胶囊与综合排行全宽周期胶囊。Top250 保持现有筛选状态和即时请求机制，仅将可拖拽内容容器替换为固定高度的内部滚动列表，并统一使用私有紧凑 `ChoiceChip`。

**Tech Stack:** Flutter, Dart, Material 3, Provider, flutter_test

## Global Constraints

- 保持 `RankingService`、OpenAPI 参数、分页、加载态、Tab 状态保留逻辑不变。
- `SortSegmented<T>` 新参数必须有保持旧行为的默认值，不能改变 `common_list_page.dart` 的现有外观。
- Top250 抽屉总高度固定为当前屏幕高度的 `2 / 3` 左右；不得使用 `DraggableScrollableSheet`，内容超出时只允许内部列表滚动。
- 保留底部抽屉的向下关闭能力和拖动把手；“不可上拉”指不能通过上拉增加抽屉高度。
- 看热播两个胶囊必须始终在同一行：左侧“高分/全部”占约 `2 / 5`，右侧“日榜/周榜/月榜”占约 `3 / 5`。
- 有码、无码、欧美、FC2 共用的日/周/月榜胶囊必须占满水平可用空间。
- 紧凑模式隐藏选中图标，使用紧凑视觉密度、收缩点击目标和较小水平内边距；仍须保留可点击性和选中状态。
- 先写失败测试，再实现最小改动；每个任务完成后运行对应测试并提交范围内文件。
- 不重置、不清理用户已有改动；提交前检查 `git status --short` 并只暂存本计划列出的文件。

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `lib/core/widgets/sort_segmented.dart` | Modify | 为共享分段胶囊增加可选的紧凑和撑满能力 |
| `test/core/widgets/sort_segmented_test.dart` | Create | 锁定默认模式兼容性及紧凑、撑满配置 |
| `lib/features/rankings/screens/rankings_screen.dart` | Modify | 固定 Top250 抽屉高度、压缩筛选项、统一排行榜胶囊布局 |
| `test/features/rankings/rankings_screen_test.dart` | Modify | 验证抽屉高度/不可上拉、紧凑样式、同排比例和全宽布局 |

## Task 1: Add Opt-in Compact and Expanded Modes to `SortSegmented`

**Files:**

- Create: `test/core/widgets/sort_segmented_test.dart`
- Modify: `lib/core/widgets/sort_segmented.dart`
- Verify: `lib/features/common/screens/common_list_page.dart`

- [ ] **Step 1: Write the shared-widget regression tests**

Create `test/core/widgets/sort_segmented_test.dart` with two widget tests:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/sort_segmented.dart';

void main() {
  testWidgets('默认模式保持原有尺寸和选中图标', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SortSegmented<String>(
            options: const [
              (label: '日榜', value: 'daily'),
              (label: '周榜', value: 'weekly'),
            ],
            value: 'daily',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final segmented = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(segmented.showSelectedIcon, isTrue);
    expect(segmented.expandedInsets, isNull);
    expect(segmented.style, isNull);
  });

  testWidgets('紧凑撑满模式应用收缩样式并填满父级', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SortSegmented<String>(
                compact: true,
                expanded: true,
                options: const [
                  (label: '日榜', value: 'daily'),
                  (label: '周榜', value: 'weekly'),
                  (label: '月榜', value: 'monthly'),
                ],
                value: 'daily',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final finder = find.byType(SegmentedButton<String>);
    final segmented = tester.widget<SegmentedButton<String>>(finder);
    expect(segmented.showSelectedIcon, isFalse);
    expect(segmented.expandedInsets, EdgeInsets.zero);
    expect(segmented.style?.visualDensity, VisualDensity.compact);
    expect(
      segmented.style?.tapTargetSize,
      MaterialTapTargetSize.shrinkWrap,
    );
    expect(
      segmented.style?.padding?.resolve(<WidgetState>{}),
      const EdgeInsets.symmetric(horizontal: 8),
    );
    expect(tester.getSize(finder).width, 300);
  });
}
```

- [ ] **Step 2: Run the tests and confirm the new API is missing**

Run:

```bash
flutter test test/core/widgets/sort_segmented_test.dart
```

Expected: compilation fails because `compact` and `expanded` are not yet constructor parameters.

- [ ] **Step 3: Implement the opt-in API**

Update `lib/core/widgets/sort_segmented.dart`:

```dart
class SortSegmented<T> extends StatelessWidget {
  const SortSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.expanded = false,
  });

  final List<({String label, T value})> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: options
          .map(
            (option) => ButtonSegment<T>(
              value: option.value,
              label: Text(option.label),
            ),
          )
          .toList(),
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
      expandedInsets: expanded ? EdgeInsets.zero : null,
      showSelectedIcon: !compact,
      style: compact
          ? const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8),
              ),
            )
          : null,
    );
  }
}
```

Do not change `lib/features/common/screens/common_list_page.dart`; its call omits both new flags and therefore retains the existing appearance.

- [ ] **Step 4: Format and run focused tests**

Run:

```bash
dart format lib/core/widgets/sort_segmented.dart test/core/widgets/sort_segmented_test.dart
flutter test test/core/widgets/sort_segmented_test.dart
flutter test test/features/common
```

Expected: all tests pass. If `test/features/common` does not exist, use the closest existing test returned by:

```bash
rg -l "CommonListPage|SortSegmented" test
```

- [ ] **Step 5: Commit the shared component change**

Run:

```bash
git status --short
git add lib/core/widgets/sort_segmented.dart test/core/widgets/sort_segmented_test.dart
git commit -m "feat: add compact segmented filter mode"
```

## Task 2: Fix Top250 Filter Sheet Height and Compact Its Choices

**Files:**

- Modify: `test/features/rankings/rankings_screen_test.dart`
- Modify: `lib/features/rankings/screens/rankings_screen.dart`

- [ ] **Step 1: Add failing height, drag, and chip-style assertions**

Extend `Top250 筛选抽屉完整展示筛选项且切换 Tab 后隐藏入口` after opening the sheet:

```dart
final sheetFinder = find.byType(BottomSheet);
expect(sheetFinder, findsOneWidget);
expect(
  tester.getSize(sheetFinder).height,
  closeTo(tester.view.physicalSize.height * 2 / 3, 2),
);
expect(find.byType(DraggableScrollableSheet), findsNothing);

final heightBeforeUpwardDrag = tester.getSize(sheetFinder).height;
await tester.drag(sheetFinder, const Offset(0, -120));
await tester.pumpAndSettle();
expect(
  tester.getSize(sheetFinder).height,
  closeTo(heightBeforeUpwardDrag, 1),
);

for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
  expect(chip.showCheckmark, isFalse);
  expect(chip.visualDensity, VisualDensity.compact);
  expect(chip.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
  expect(chip.labelPadding, const EdgeInsets.symmetric(horizontal: 6));
}
```

Replace `_scrollFilterSheetToBottom` with one internal-list drag, because there is no longer an initial drag-to-expand phase:

```dart
Future<void> _scrollFilterSheetToBottom(WidgetTester tester) async {
  final list = find.byKey(const Key('top250-filter-list'));
  await tester.drag(list, const Offset(0, -800));
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: Run the existing rankings test and confirm failure**

Run:

```bash
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "Top250 筛选抽屉完整展示筛选项且切换 Tab 后隐藏入口"
```

Expected: failure because the sheet is currently capped at 90%, contains `DraggableScrollableSheet`, and uses default `ChoiceChip` styling.

- [ ] **Step 3: Make the modal itself exactly two-thirds height**

In `_showTop250Filter`, replace the 90% maximum constraint with a fixed constraint:

```dart
final sheetHeight = MediaQuery.sizeOf(context).height * 2 / 3;
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: BoxConstraints.tightFor(height: sheetHeight),
  builder: (_) => _Top250FilterSheet(
    value: _top250Filter,
    onChanged: (value) => setState(() => _top250Filter = value),
  ),
);
```

Keep the default downward-dismiss behavior; do not set `enableDrag: false`.

- [ ] **Step 4: Replace `DraggableScrollableSheet` with an internal list**

Replace `_Top250FilterSheetState.build` outer container with:

```dart
return ListView(
  key: const Key('top250-filter-list'),
  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
  children: [
    Text('筛选', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 12),
    // compact type/year choices
    const SizedBox(height: 16),
    Text('起始排名', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    // compact start-rank choices
    const SizedBox(height: 8),
    // existing SwitchListTile
  ],
);
```

Remove `initialChildSize`, `minChildSize`, `maxChildSize`, and the scroll controller supplied by `DraggableScrollableSheet`. The `ListView` owns scrolling, so upward gestures scroll content without increasing modal height.

- [ ] **Step 5: Add and use one private compact chip widget**

Add below `_Top250FilterSheetState`:

```dart
class _CompactChoiceChip extends StatelessWidget {
  const _CompactChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
```

Use `_CompactChoiceChip` for “全部”、four video types, every year, and five start ranks. Set both `Wrap` widgets to:

```dart
spacing: 8,
runSpacing: 8,
```

Keep each callback’s existing `_emit(...)` value unchanged so filtering still refreshes immediately.

- [ ] **Step 6: Run all Top250 interaction tests**

Run:

```bash
dart format lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "Top250 筛选抽屉完整展示筛选项且切换 Tab 后隐藏入口"
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "Top250 筛选立即刷新并保持抽屉打开"
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "Top250 未登录时不请求且登录后自动加载"
```

Expected: sheet-height/style assertions pass, all `type`/`type_value`/`start_rank`/`ignore_watched` requests remain unchanged, and the sheet stays open after selections.

- [ ] **Step 7: Commit the Top250 sheet change**

Run:

```bash
git status --short
git add lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
git commit -m "feat: compact Top250 filter sheet"
```

## Task 3: Unify Hot-play and Rank-period Capsules

**Files:**

- Modify: `test/features/rankings/rankings_screen_test.dart`
- Modify: `lib/features/rankings/screens/rankings_screen.dart`

- [ ] **Step 1: Replace the hot-play style test with row-layout assertions**

Update `看热播使用分组圆角标签并发送 OpenAPI 参数`:

```dart
expect(find.text('范围'), findsNothing);
expect(find.text('周期'), findsNothing);
expect(find.byType(ChoiceChip), findsNothing);

final row = find.byKey(const Key('hot-play-filter-row'));
final range = find.byKey(const Key('hot-play-range-filter'));
final period = find.byKey(const Key('hot-play-period-filter'));
expect(row, findsOneWidget);
expect(range, findsOneWidget);
expect(period, findsOneWidget);
expect(tester.getTopLeft(range).dy, tester.getTopLeft(period).dy);
expect(
  tester.getSize(range).width / tester.getSize(period).width,
  closeTo(2 / 3, 0.08),
);

for (final finder in [range, period]) {
  final segmented = tester.widget<SegmentedButton<String>>(
    find.descendant(
      of: finder,
      matching: find.byType(SegmentedButton<String>),
    ),
  );
  expect(segmented.showSelectedIcon, isFalse);
  expect(segmented.expandedInsets, EdgeInsets.zero);
}

await tester.tap(find.text('周榜'));
await _pumpRankingFrame(tester);
```

Retain the existing query assertions for `filter_by=high_score` and `period=weekly`.

- [ ] **Step 2: Add a full-width rank-period regression test**

Add:

```dart
testWidgets('综合排行榜周期胶囊紧凑并撑满屏幕', (tester) async {
  await _pumpRankings(tester);
  await _showTab(tester, 2);

  final filter = find.byKey(const Key('rank-period-filter'));
  expect(filter, findsOneWidget);
  expect(tester.getSize(filter).width, closeTo(320 - 16, 1));

  final segmented = tester.widget<SegmentedButton<String>>(
    find.descendant(
      of: filter,
      matching: find.byType(SegmentedButton<String>),
    ),
  );
  expect(segmented.showSelectedIcon, isFalse);
  expect(segmented.expandedInsets, EdgeInsets.zero);
  expect(segmented.style?.visualDensity, VisualDensity.compact);
});
```

Keep the existing “综合排行榜没有演员月榜且类型映射从 0 开始” test; it covers all four `_RankTab` instances through their shared implementation and API type mapping.

- [ ] **Step 3: Strengthen the narrow-screen large-text test**

In `看热播筛选在窄屏大字体下不溢出`, assert both filters remain aligned:

```dart
final range = find.byKey(const Key('hot-play-range-filter'));
final period = find.byKey(const Key('hot-play-period-filter'));
expect(tester.getTopLeft(range).dy, tester.getTopLeft(period).dy);
expect(tester.takeException(), isNull);
```

- [ ] **Step 4: Run the three tests and confirm they fail**

Run:

```bash
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "看热播使用分组圆角标签并发送 OpenAPI 参数"
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "综合排行榜周期胶囊紧凑并撑满屏幕"
flutter test test/features/rankings/rankings_screen_test.dart \
  --plain-name "看热播筛选在窄屏大字体下不溢出"
```

Expected: failures because hot-play still renders two labeled chip rows and `_RankTab` still uses an intrinsic-width default segmented button.

- [ ] **Step 5: Implement the hot-play two-capsule row**

Replace `_HotPlayTabState.build` filter `Column` with:

```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  child: Row(
    key: const Key('hot-play-filter-row'),
    children: [
      Expanded(
        flex: 2,
        child: SortSegmented<String>(
          key: const Key('hot-play-range-filter'),
          compact: true,
          expanded: true,
          options: const [
            (label: '高分', value: 'high_score'),
            (label: '全部', value: 'all'),
          ],
          value: _filterBy,
          onChanged: _updateFilterBy,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 3,
        child: SortSegmented<String>(
          key: const Key('hot-play-period-filter'),
          compact: true,
          expanded: true,
          options: const [
            (label: '日榜', value: 'daily'),
            (label: '周榜', value: 'weekly'),
            (label: '月榜', value: 'monthly'),
          ],
          value: _period,
          onChanged: _updatePeriod,
        ),
      ),
    ],
  ),
),
```

Delete `_FilterChipRow`; it has no remaining callers. Do not add a `Wrap`, so the two filters cannot move onto separate rows.

- [ ] **Step 6: Make rank-period capsules compact and full-width**

Update `_RankTabState.build`:

```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  child: SortSegmented<String>(
    key: const Key('rank-period-filter'),
    compact: true,
    expanded: true,
    options: periods,
    value: _period,
    onChanged: _updatePeriod,
  ),
),
```

All four tabs reuse `_RankTab`, so this one change covers 有码、无码、欧美、FC2.

- [ ] **Step 7: Run rankings and shared-widget tests**

Run:

```bash
dart format lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
flutter test test/core/widgets/sort_segmented_test.dart
flutter test test/features/rankings/rankings_screen_test.dart
flutter test test/api_integration_test.dart --plain-name RankingService
```

Expected: all pass; the hot-play request still uses `filter_by` and `period`, and rank requests still use type values `0` through `3`.

- [ ] **Step 8: Commit the ranking filter layout**

Run:

```bash
git status --short
git add lib/features/rankings/screens/rankings_screen.dart test/features/rankings/rankings_screen_test.dart
git commit -m "feat: unify compact ranking filters"
```

## Task 4: Full Verification and Android Visual Validation

**Files:**

- Verify all files listed above
- Save screenshots only under `/tmp` unless the user requests persistent artifacts

- [ ] **Step 1: Run formatting check and static analysis**

Run:

```bash
dart format --output=none --set-exit-if-changed \
  lib/core/widgets/sort_segmented.dart \
  lib/features/rankings/screens/rankings_screen.dart \
  test/core/widgets/sort_segmented_test.dart \
  test/features/rankings/rankings_screen_test.dart
flutter analyze
```

Expected: format check exits 0 and analysis reports no issues.

- [ ] **Step 2: Run the full test suite**

Run:

```bash
flutter test
```

Expected: all tests pass. Record the exact pass count in the handoff.

- [ ] **Step 3: Confirm the final diff is scoped**

Run:

```bash
git status --short
git diff HEAD~3 --stat
git diff HEAD~3 -- \
  lib/core/widgets/sort_segmented.dart \
  lib/features/rankings/screens/rankings_screen.dart \
  test/core/widgets/sort_segmented_test.dart \
  test/features/rankings/rankings_screen_test.dart
```

Expected: only compact-filter implementation and tests appear; no service, OpenAPI, pagination, or unrelated page changes.

- [ ] **Step 4: Build and install the debug APK**

Run:

```bash
flutter build apk --debug
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Prefer the mounted `adb_tool` connector when it is available. If it is not mounted in the execution session, use the local `adb` binary and state that fallback explicitly in the final report.

- [ ] **Step 5: Validate the Top250 sheet on-device**

Launch package `xxx.porn.jdb`, navigate to “排行榜”, open “筛选 Top250”, then verify:

1. The modal occupies approximately two-thirds of the visible screen.
2. An upward swipe inside the sheet scrolls filter content but does not increase modal height.
3. Type/year/start-rank choices are visibly denser, have no checkmark, and remain selectable.
4. Selecting a filter keeps the sheet open and refreshes the Top250 result.

Capture a screenshot:

```bash
adb exec-out screencap -p > /tmp/rankings-top250-compact.png
```

- [ ] **Step 6: Validate hot-play and all rank tabs on-device**

Verify:

1. 看热播 displays “高分/全部” and “日榜/周榜/月榜” on the same row.
2. The left and right capsules have an approximately `2:3` width relationship.
3. 有码、无码、欧美、FC2 each display a compact period capsule spanning the available screen width.
4. None of the four rank tabs shows “演员月榜”.
5. Switching tabs retains the previous content while new data loads without a blank intermediate screen.

Capture a screenshot:

```bash
adb exec-out screencap -p > /tmp/rankings-compact-filters.png
```

- [ ] **Step 7: Check repository state and report evidence**

Run:

```bash
git status --short
git log --oneline -6
```

The final report must include:

- changed behavior and affected tabs;
- focused-test, full-test, analyze, and APK build results;
- ADB device identifier and whether the connector or local fallback was used;
- screenshot paths;
- final commit hashes;
- any unrelated pre-existing worktree changes left untouched.
