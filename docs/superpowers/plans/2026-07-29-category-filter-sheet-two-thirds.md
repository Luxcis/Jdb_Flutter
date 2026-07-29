# Category Filter Sheet Two-Thirds Height Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将分类筛选底部面板固定为可视屏幕高度的三分之二。

**Architecture:** 保留现有 `showModalBottomSheet` 和
`CategoryFilterSheet`，只调整页面计算并传入的高度约束。使用现有页面 Widget
测试验证精确比例、动态内容和即时筛选行为，不新增组件或依赖。

**Tech Stack:** Flutter、Material 3、`flutter_test`

## Global Constraints

- 面板高度固定为当前可视屏幕高度的 `2 / 3`。
- 不增加拖动扩展到全屏的行为。
- 保留安全区域、拖动手柄和筛选内容内部滚动。
- 不修改动态标签、即时筛选、Tab 独立状态或影片分页逻辑。
- 不新增依赖。

---

### Task 1: 将筛选面板高度调整为三分之二

**Files:**
- Modify: `test/features/categories/categories_screen_test.dart:196-215`
- Modify: `lib/features/categories/screens/categories_screen.dart:50-58`

**Interfaces:**
- Consumes: `MediaQuery.sizeOf(BuildContext).height`
- Produces: 固定高度为 `screenHeight * 2 / 3` 的分类筛选底部面板

- [ ] **Step 1: 修改现有 Widget 测试，使其表达三分之二高度**

```dart
expect(
  tester.getSize(find.byType(BottomSheet)).height,
  closeTo(844 * 2 / 3, 1),
);
```

测试仍保留动态分组、点击筛选项即时请求以及面板保持打开的断言。

- [ ] **Step 2: 运行定向测试并确认旧实现失败**

Run:

```bash
flutter test test/features/categories/categories_screen_test.dart \
  --plain-name '筛选面板内容来自当前 Tab 标签接口且点击后保持打开'
```

Expected: FAIL；实际高度约为 `844 * .9`，不等于 `844 * 2 / 3`。

- [ ] **Step 3: 将面板高度约束改为三分之二**

```dart
void _showFilter() {
  final height = MediaQuery.sizeOf(context).height * 2 / 3;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints.tightFor(height: height),
    builder: (_) =>
        CategoryFilterSheet(controller: _controllers[_selectedIndex]),
  );
}
```

- [ ] **Step 4: 格式化并运行分类页面测试**

Run:

```bash
dart format lib/features/categories/screens/categories_screen.dart \
  test/features/categories/categories_screen_test.dart
flutter test test/features/categories/categories_screen_test.dart
```

Expected: PASS；高度断言、动态内容和即时筛选行为均通过。

- [ ] **Step 5: 运行全量验证**

Run:

```bash
flutter test
flutter analyze
git diff --check
git status --short
```

Expected: 全量测试通过；静态分析输出 `No issues found!`；差异无空白错误；
工作树只包含本任务的页面和测试文件。

- [ ] **Step 6: 提交实现**

```bash
git add lib/features/categories/screens/categories_screen.dart \
  test/features/categories/categories_screen_test.dart
git commit -m "fix(categories): reduce filter sheet height"
```
