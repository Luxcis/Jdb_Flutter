# 排行榜默认 Tab 改为"有码" 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或
> superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 排行榜页面进入时默认选中"有码"tab（索引 2），替代当前的 Top250（索引 0）。

**架构：** 修改 `RankingsPage` 构造函数的 `initialTabIndex` 默认值从 0 改为 2，同步更新路由 fallback
值和测试用例。

**技术栈：** Flutter / Dart

---

### 任务 1：修改 RankingsPage 默认 tab 索引

**文件：**

- 修改：`lib/features/rankings/screens/rankings_screen.dart:17`

- [ ] **步骤 1：修改构造函数默认值**

```dart
// 修改前
const RankingsPage({super.key, this.initialTabIndex = 0})

// 修改后
const RankingsPage({super.key, this.initialTabIndex = 2})
```

- [ ] **步骤 2：运行静态分析确认无编译错误**

运行：
`cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/features/rankings/screens/rankings_screen.dart`
预期：无错误

- [ ] **步骤 3：Commit**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/features/rankings/screens/rankings_screen.dart
git commit -m "feat: 排行榜默认 tab 改为有码（index 0→2）"
```

---

### 任务 2：修改路由 fallback 值

**文件：**

- 修改：`lib/core/router/app_router.dart:90`

- [ ] **步骤 1：修改路由三元表达式**

```dart
// 修改前
initialTabIndex: state.uri.queryParameters['tab'] == 'hot' ? 1 : 0,

// 修改后
initialTabIndex: state.uri.queryParameters['tab'] == 'hot' ? 1 : 2,
```

- [ ] **步骤 2：运行静态分析确认无编译错误**

运行：
`cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && dart analyze lib/core/router/app_router.dart`
预期：无错误

- [ ] **步骤 3：Commit**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add lib/core/router/app_router.dart
git commit -m "feat: 路由默认 fallback 改为有码 tab（0→2）"
```

---

### 任务 3：更新测试用例

**文件：**

- 修改：`test/features/rankings/rankings_screen_test.dart:43,312,359,415,439,481,501,529,582,626`

**变更说明：**

1. `_pumpRankings` 的 `initialTabIndex` 默认值从 `0` 改为 `2`，与 app 默认保持一致
2. 所有测试 Top250（tab 0）行为的用例，显式传入 `initialTabIndex: 0`

- [ ] **步骤 1：修改 `_pumpRankings` 默认值（第 43 行）**

```dart
// 修改前
int initialTabIndex = 0,

// 修改后
int initialTabIndex = 2,
```

- [ ] **步骤 2：Top250 筛选抽屉测试传入 initialTabIndex: 0（第 312-313 行）**

```dart
// 修改前
await _pumpRankings(tester);
await _pumpRankingFrame(tester);

// 修改后
await _pumpRankings(tester, initialTabIndex: 0);
await _pumpRankingFrame(tester);
```

- [ ] **步骤 3：Top250 筛选立即刷新测试传入 initialTabIndex: 0（第 359-360 行）**

```dart
// 修改前
final fixture = await _pumpRankings(tester);
await _pumpRankingFrame(tester);

// 修改后
final fixture = await _pumpRankings(tester, initialTabIndex: 0);
await _pumpRankingFrame(tester);
```

- [ ] **步骤 4：Top250 未登录测试传入 initialTabIndex: 0（第 415-416 行）**

```dart
// 修改前
final fixture = await _pumpRankings(tester, loggedIn: false);
await _pumpRankingFrame(tester);

// 修改后
final fixture = await _pumpRankings(tester, loggedIn: false, initialTabIndex: 0);
await _pumpRankingFrame(tester);
```

- [ ] **步骤 5：Top250 滚动追加测试传入 initialTabIndex: 0（第 439-443 行）**

```dart
// 修改前
final fixture = await _pumpRankings(
  tester,
  top250Responses: [_top250Response(1, 50), _top250Response(51, 50)],
);

// 修改后
final fixture = await _pumpRankings(
  tester,
  initialTabIndex: 0,
  top250Responses: [_top250Response(1, 50), _top250Response(51, 50)],
);
```

- [ ] **步骤 6：Top250 首批不足 50 条测试传入 initialTabIndex: 0（第 481-483 行）**

```dart
// 修改前
final fixture = await _pumpRankings(
  tester,
  top250Responses: [_top250Response(1, 10)],
);

// 修改后
final fixture = await _pumpRankings(
  tester,
  initialTabIndex: 0,
  top250Responses: [_top250Response(1, 10)],
);
```

- [ ] **步骤 7：Top250 从 201 开始测试传入 initialTabIndex: 0（第 501-506 行）**

```dart
// 修改前
final fixture = await _pumpRankings(
  tester,
  top250Responses: [_top250Response(1, 1), _top250Response(201, 50)],
);

// 修改后
final fixture = await _pumpRankings(
  tester,
  initialTabIndex: 0,
  top250Responses: [_top250Response(1, 1), _top250Response(201, 50)],
);
```

- [ ] **步骤 8：Top250 从 51 开始测试传入 initialTabIndex: 0（第 529-538 行）**

```dart
// 修改前
final fixture = await _pumpRankings(
  tester,
  top250Responses: [
    _top250Response(1, 1),
    _top250Response(51, 50),
    _top250Response(101, 50),
  ],
);

// 修改后
final fixture = await _pumpRankings(
  tester,
  initialTabIndex: 0,
  top250Responses: [
    _top250Response(1, 1),
    _top250Response(51, 50),
    _top250Response(101, 50),
  ],
);
```

- [ ] **步骤 9：Top250 追加失败重试测试传入 initialTabIndex: 0（第 582-590 行）**

```dart
// 修改前
final fixture = await _pumpRankings(
  tester,
  top250Responses: [
    _top250Response(1, 50),
    {'success': 0, 'message': 'next page failed'},
    _top250Response(51, 50),
  ],
);

// 修改后
final fixture = await _pumpRankings(
  tester,
  initialTabIndex: 0,
  top250Responses: [
    _top250Response(1, 50),
    {'success': 0, 'message': 'next page failed'},
    _top250Response(51, 50),
  ],
);
```

- [ ] **步骤 10：Top250 影片点击测试传入 initialTabIndex: 0（第 626-627 行）**

```dart
// 修改前
final fixture = await _pumpRankings(tester, withRouter: true);
await _pumpRankingFrame(tester);

// 修改后
final fixture = await _pumpRankings(tester, withRouter: true, initialTabIndex: 0);
await _pumpRankingFrame(tester);
```

- [ ] **步骤 11：运行测试验证全部通过**

运行：
`cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter && flutter test test/features/rankings/rankings_screen_test.dart`
预期：所有测试 PASS

- [ ] **步骤 12：Commit**

```bash
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890 all_proxy=socks5://127.0.0.1:7890
git add test/features/rankings/rankings_screen_test.dart
git commit -m "test: 更新排行榜测试默认 tab 为有码"
```
