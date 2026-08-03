# Search Landing Hot Keywords Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将搜索入口页限制为非空历史和 startup 近期热词，并把现有七类结果迁移到独立结果路由。

**Architecture:** `StartupData` 与 `StartupProvider` 负责本次启动周期的 `recent_keywords`，共享的可监听 `SearchHistoryStore` 负责本地历史规范化、持久化及跨页面同步。`SearchPage` 只渲染入口内容并 push 到嵌套结果路由，`SearchResultsPage` 承接现有结果 Tab 并在重新搜索时 replace 当前 URI。

**Tech Stack:** Flutter Material 3、Dart、Provider、go_router、SharedPreferences、json_serializable、flutter_test

## Global Constraints

- 只接入 startup 的 `recent_keywords`，不处理 `recent_magnet_keywords`。
- 搜索入口页不渲染任何结果 Tab。
- 历史模块在历史为空时完全隐藏；近期热搜模块在热词为空时完全隐藏。
- 历史标题与清空按钮同行，清空按钮位于屏幕右侧。
- 模块标题使用 `titleLarge` 加粗样式；关键词使用紧凑 `ActionChip` 和可换行 `Wrap`。
- 历史去重、最近优先、最多 20 条；无效缓存按空列表处理。
- 有效搜索 push 到 `/search/results?q=<关键词>`；结果页重新搜索使用 replace。
- 不新增第三方依赖，不改变现有七类搜索接口参数。

---

### Task 1: Startup 近期热词数据链路

**Files:**
- Modify: `lib/core/models/startup.dart`
- Generate: `lib/core/models/startup.g.dart`
- Modify: `lib/core/providers/startup_provider.dart`
- Modify: `test/core/providers/startup_provider_test.dart`
- Create: `test/core/models/startup_test.dart`

**Interfaces:**
- Produces: `StartupData.recentKeywords: List<String>`
- Produces: `StartupProvider.recentKeywords: List<String>`

- [x] **Step 1: 写模型与 Provider 的失败测试**

```dart
test('解析 recent_keywords 且缺失时默认为空列表', () {
  expect(
    StartupData.fromJson({'recent_keywords': ['演员', 'ABP-001']})
        .recentKeywords,
    ['演员', 'ABP-001'],
  );
  expect(StartupData.fromJson(const {}).recentKeywords, isEmpty);
});

test('成功时暴露 startup 近期热词', () async {
  final api = _FakeStartupApi([
    () => const StartupData(
      backupDomainsData: 'ciphertext',
      recentKeywords: ['演员', 'ABP-001'],
    ),
  ]);
  final subject = await _createSubject(api);

  expect(await subject.provider.load(), isTrue);
  expect(subject.provider.recentKeywords, ['演员', 'ABP-001']);
});
```

- [x] **Step 2: 运行测试确认字段不存在而失败**

Run: `flutter test test/core/models/startup_test.dart test/core/providers/startup_provider_test.dart`

Expected: FAIL，`recentKeywords` 未定义。

- [x] **Step 3: 实现模型默认值与 Provider 成功态赋值**

```dart
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class StartupData {
  const StartupData({
    this.backupDomainsData,
    this.recentKeywords = const [],
    this.settings,
    this.user,
  });

  final String? backupDomainsData;
  final List<String> recentKeywords;
  // existing fields
}
```

Provider 增加 `_recentKeywords` 与 getter，并仅在域名应用成功后执行：

```dart
_recentKeywords = List<String>.unmodifiable(startup.recentKeywords);
_status = StartupStatus.success;
```

- [x] **Step 4: 生成 JSON 代码并运行测试**

Run: `dart run build_runner build --delete-conflicting-outputs`

Run: `dart format lib/core/models/startup.dart lib/core/providers/startup_provider.dart test/core/models/startup_test.dart test/core/providers/startup_provider_test.dart`

Run: `flutter test test/core/models/startup_test.dart test/core/providers/startup_provider_test.dart`

Expected: PASS。

### Task 2: 搜索历史存储边界

**Files:**
- Create: `lib/features/search/services/search_history_store.dart`
- Create: `test/features/search/search_history_store_test.dart`

**Interfaces:**
- Produces: `SearchHistoryStore(SharedPreferences prefs) extends ChangeNotifier`
- Produces: `List<String> load()`、`Future<List<String>> save(String query)`、`Future<void> clear()`

- [x] **Step 1: 写历史存储失败测试**

```dart
test('保存时去重、最近优先并最多保留 20 条', () async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.searchHistory: jsonEncode([
      for (var index = 0; index < 20; index++) '关键词$index',
    ]),
  });
  final store = SearchHistoryStore(await SharedPreferences.getInstance());

  expect(await store.save('  关键词5  '), [
    '关键词5',
    '关键词0',
    '关键词1',
    '关键词2',
    '关键词3',
    '关键词4',
    ...[for (var index = 6; index < 20; index++) '关键词$index'],
  ]);
});

test('无效 JSON 和非字符串项按空历史处理', () async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.searchHistory: '{invalid',
  });
  final store = SearchHistoryStore(await SharedPreferences.getInstance());
  expect(store.load(), isEmpty);
});
```

- [x] **Step 2: 运行测试确认存储类型不存在而失败**

Run: `flutter test test/features/search/search_history_store_test.dart`

Expected: FAIL，`SearchHistoryStore` 未定义。

- [x] **Step 3: 实现历史读取、保存与清空**

```dart
class SearchHistoryStore extends ChangeNotifier {
  SearchHistoryStore(this._prefs);
  final SharedPreferences _prefs;

  List<String> load() {
    final raw = _prefs.getString(StorageKeys.searchHistory);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.any((item) => item is! String)) {
        return const [];
      }
      return List<String>.from(decoded);
    } on FormatException {
      return const [];
    }
  }

  Future<List<String>> save(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) return load();
    final history = load()..remove(keyword);
    history.insert(0, keyword);
    final limited = history.take(20).toList(growable: false);
    await _prefs.setString(StorageKeys.searchHistory, jsonEncode(limited));
    notifyListeners();
    return limited;
  }

  Future<void> clear() => _prefs.remove(StorageKeys.searchHistory);
}
```

- [x] **Step 4: 格式化并运行存储测试**

Run: `dart format lib/features/search/services/search_history_store.dart test/features/search/search_history_store_test.dart`

Run: `flutter test test/features/search/search_history_store_test.dart`

Expected: PASS。

### Task 3: 搜索入口页与独立结果路由

**Files:**
- Modify: `lib/core/router/routes.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/search/screens/search_screen.dart`
- Create: `lib/features/search/screens/search_results_screen.dart`
- Modify: `lib/features/search/index.dart`
- Modify: `lib/main.dart`
- Create: `test/features/search/search_screen_test.dart`
- Modify: `test/app_router_test.dart`

**Interfaces:**
- Consumes: `SearchHistoryStore`、`StartupProvider.recentKeywords`
- Produces: `AppRoutes.searchResults = '/search/results'`
- Produces: `SearchPage({SearchHistoryStore? historyStore, List<String>? recentKeywords})`
- Produces: `SearchResultsPage({required String query, SearchHistoryStore? historyStore})`

- [x] **Step 1: 写入口页布局、空模块和导航失败测试**

```dart
testWidgets('仅显示非空历史和热词并将清空按钮放在历史标题右侧', (tester) async {
  final store = await _storeWithHistory(['历史番号']);
  await tester.pumpWidget(
    MaterialApp(
      home: SearchPage(
        historyStore: store,
        recentKeywords: const ['热门演员'],
      ),
    ),
  );
  await tester.pump();

  expect(find.text('历史搜索'), findsOneWidget);
  expect(find.text('近期热搜'), findsOneWidget);
  expect(find.byType(TabBar), findsNothing);
  expect(
    tester.getCenter(find.text('清空')).dx,
    greaterThan(tester.getCenter(find.text('历史搜索')).dx),
  );
});

testWidgets('历史和热词为空时隐藏两个模块', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SearchPage(
        historyStore: await _storeWithHistory(const []),
        recentKeywords: const [],
      ),
    ),
  );
  await tester.pump();
  expect(find.text('历史搜索'), findsNothing);
  expect(find.text('近期热搜'), findsNothing);
});
```

使用真实 `GoRouter` 增加提交测试：

```dart
final router = GoRouter(
  initialLocation: AppRoutes.search,
  routes: [
    GoRoute(
      path: AppRoutes.search,
      builder: (_, _) => SearchPage(
        historyStore: store,
        recentKeywords: const ['热门演员'],
      ),
      routes: [
        GoRoute(
          path: 'results',
          builder: (_, state) => Scaffold(
            body: Text('结果 ${state.uri.queryParameters['q']}'),
          ),
        ),
      ],
    ),
  ],
);
await tester.pumpWidget(MaterialApp.router(routerConfig: router));
await tester.enterText(find.byType(TextField), ' ABP-001 ');
await tester.testTextInput.receiveAction(TextInputAction.done);
await tester.pumpAndSettle();
expect(router.state.uri.toString(), '/search/results?q=ABP-001');
expect(store.load().first, 'ABP-001');
```

- [x] **Step 2: 写结果页与路由失败测试**

```dart
testWidgets('结果路由显示七个 Tab 且入口页不显示结果', (tester) async {
  final router = AppRouter.buildForTest(initialLocation: '/search/results?q=ABP-001');
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();

  expect(find.text('影片'), findsOneWidget);
  expect(find.text('演员'), findsOneWidget);
  expect(find.text('番号'), findsOneWidget);
});

testWidgets('结果路由缺少 q 时返回搜索入口页', (tester) async {
  final router = AppRouter.buildForTest(initialLocation: AppRoutes.searchResults);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  expect(router.state.uri.path, AppRoutes.search);
});
```

- [x] **Step 3: 运行测试确认旧页面仍内嵌结果且新路由不存在**

Run: `flutter test test/features/search/search_screen_test.dart test/app_router_test.dart --plain-name '搜索|结果路由'`

Expected: FAIL，入口页构造参数或 `AppRoutes.searchResults` 未定义。

- [x] **Step 4: 实现入口页的非空模块和紧凑标签**

入口页从注入值或可选的 `context.watch<StartupProvider?>()?.recentKeywords` 取热词，因此没有 StartupProvider 的独立 Widget 测试仍按空热词工作。历史加载后按条件组合模块：

```dart
if (_history.isNotEmpty) ...[
  Row(
    children: [
      Text('历史搜索', style: titleStyle),
      const Spacer(),
      TextButton(onPressed: _clearHistory, child: const Text('清空')),
    ],
  ),
  _KeywordWrap(keywords: _history, onSelected: _search),
],
if (recentKeywords.isNotEmpty) ...[
  Text('近期热搜', style: titleStyle),
  _KeywordWrap(keywords: recentKeywords, onSelected: _search),
],
```

`_KeywordWrap` 使用 `ActionChip(visualDensity: VisualDensity.compact)` 与 `Wrap(spacing: 8, runSpacing: 8)`。

- [x] **Step 5: 拆出结果页并注册嵌套路由**

将现有 `_ResultView` 及七类 Tab 移到 `search_results_screen.dart`，公开：

```dart
class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({super.key, required this.query, this.historyStore});
  final String query;
  final SearchHistoryStore? historyStore;
}
```

在 `/search` 下注册 child route：

```dart
GoRoute(
  path: AppRoutes.search,
  builder: (_, _) => const SearchPage(),
  routes: [
    GoRoute(
      path: 'results',
      redirect: (_, state) {
        final query = state.uri.queryParameters['q']?.trim() ?? '';
        return query.isEmpty ? AppRoutes.search : null;
      },
      builder: (_, state) => SearchResultsPage(
        key: state.pageKey,
        query: state.uri.queryParameters['q']!.trim(),
      ),
    ),
  ],
),
```

入口页使用 `context.push(Uri(path: AppRoutes.searchResults, queryParameters: {'q': keyword}).toString())`；结果页重新提交时保存历史并调用 `context.replace(...)`。

在 `main.dart` 注册同一个 `SearchHistoryStore`，入口页监听其变更，使结果页二次搜索写入缓存后，返回入口页可立即看到最新历史。

- [x] **Step 6: 格式化并运行搜索与路由测试**

Run: `dart format lib/core/router/routes.dart lib/core/router/app_router.dart lib/features/search test/features/search test/app_router_test.dart`

Run: `flutter test test/features/search/search_screen_test.dart test/app_router_test.dart`

Expected: PASS。

### Task 4: 全量验证与交付

**Files:**
- Verify: all Task 1-3 files

**Interfaces:**
- Consumes: startup 热词、历史存储、入口页和结果页完整链路
- Produces: 可提交的两级搜索体验

- [x] **Step 1: 运行相关测试**

Run: `flutter test test/core/models/startup_test.dart test/core/providers/startup_provider_test.dart test/features/search/search_history_store_test.dart test/features/search/search_screen_test.dart test/app_router_test.dart`

Expected: PASS。

- [x] **Step 2: 运行完整测试和静态分析**

Run: `flutter test`

Expected: PASS，0 failures。

Run: `flutter analyze`

Expected: `No issues found!`

- [x] **Step 3: 检查格式、差异和范围**

Run: `git diff --check`

Expected: 无输出，退出码 0。

Run: `git status --short && git diff --stat && git diff`

Expected: 仅包含本计划列出的模型、Provider、搜索 feature、路由、生成文件、测试和本计划文件。
