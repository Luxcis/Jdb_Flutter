# Magnet Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从首页“找磁链”进入独立磁链搜索首页，使用 startup 热词和独立历史发起搜索，并在支持四种排序、自动分页和点击复制的结果页展示磁链。

**Architecture:** 在 `features/search` 内新增磁链筛选模型、数据源、首页和结果页；startup 与缓存能力通过现有 core 层扩展。将影片详情页私有磁链项抽到 core 共享组件，让详情页和搜索结果页使用同一视觉与复制逻辑；分页继续复用 `PaginationController<Magnet>`。

**Tech Stack:** Flutter Material 3、Dart、Provider、go_router、Dio、SharedPreferences、flutter_test。

## Global Constraints

- `/api/v1/search_magnet` 必须发送 `q`、`sort_by`、`from_recent`、`page`、`limit=48`。
- 磁链历史使用独立缓存，不读写普通搜索的 `key_search_history`。
- 历史入口发送字符串 `from_recent=true`；手输、热词、结果页重新搜索发送字符串 `false`。
- 四项排序复用排行榜 `SortSegmented` 的 `compact=true`、`expanded=true` 样式并等宽铺满。
- 结果项与影片详情页共用 `MagnetListTile`，点击复制完整 magnet URI 并提示“磁力链接已复制”。
- 分页从 1 开始；满 48 条推断可能有下一页，少于 48 条结束。
- 保持 Material 3、系统亮暗主题、硬编码中文；不新增依赖、ARB/l10n 或触觉反馈。
- 新公共 API 写简洁 dartdoc；使用 `dart format` 并保持 feature-first 依赖方向。

---

## File Structure

- `lib/core/models/startup.dart`、`startup.g.dart`：startup 磁链热词模型和 JSON 映射。
- `lib/core/providers/startup_provider.dart`：启动成功后持有不可变磁链热词。
- `lib/core/storage/storage_keys.dart`、`search_history_store.dart`：独立历史键和可配置存储。
- `lib/features/search/models/magnet_search_sort.dart`：排序文案和 API 值。
- `lib/features/search/services/magnet_search_service.dart`：磁链分页请求与解析。
- `lib/core/widgets/magnet_list_tile.dart`：详情页和搜索结果共用的磁链行、徽标、复制和分隔线。
- `lib/features/search/widgets/search_keyword_section.dart`：两个搜索首页共用的历史/热词展示。
- `magnet_search_screen.dart`、`magnet_search_results_screen.dart`：磁链搜索入口和结果状态。
- `lib/core/router`、`lib/features/search/index.dart`、`endpoints.dart`：路由、导出和端点注册。

---

### Task 1: Startup 磁链热词与独立历史

**Files:**
- Modify: `lib/core/models/startup.dart`
- Modify: `lib/core/models/startup.g.dart`
- Modify: `lib/core/providers/startup_provider.dart`
- Modify: `lib/core/storage/storage_keys.dart`
- Modify: `lib/features/search/services/search_history_store.dart`
- Test: `test/core/models/startup_test.dart`
- Test: `test/core/providers/startup_provider_test.dart`
- Test: `test/features/search/search_history_store_test.dart`

**Interfaces:**
- Consumes: startup JSON `recent_magnet_keywords`、`SharedPreferences`。
- Produces: `StartupData.recentMagnetKeywords`、`StartupProvider.recentMagnetKeywords`、`StorageKeys.magnetSearchHistory`、`SearchHistoryStore(prefs, {storageKey})`。

- [ ] **Step 1: 写失败的 startup 解析与 Provider 测试**

```dart
test('解析 recent_magnet_keywords 字符串列表', () {
  final startup = StartupData.fromJson({
    'recent_magnet_keywords': ['桥本香菜', '蜘蛛侠'],
  });
  expect(startup.recentMagnetKeywords, ['桥本香菜', '蜘蛛侠']);
});

test('缺少 recent_magnet_keywords 时默认为空列表', () {
  expect(StartupData.fromJson(const {}).recentMagnetKeywords, isEmpty);
});
```

Provider fixture 增加 `recentMagnetKeywords: ['桥本香菜']`，成功加载后断言 getter 返回该列表。

- [ ] **Step 2: 写失败的历史隔离测试**

```dart
test('磁链历史独立且清空不影响普通历史', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final ordinary = SearchHistoryStore(prefs);
  final magnet = SearchHistoryStore(
    prefs,
    storageKey: StorageKeys.magnetSearchHistory,
  );
  await ordinary.save('ABP-001');
  await magnet.save('桥本香菜');
  expect(ordinary.load(), ['ABP-001']);
  expect(magnet.load(), ['桥本香菜']);
  await magnet.clear();
  expect(ordinary.load(), ['ABP-001']);
  expect(magnet.load(), isEmpty);
});
```

- [ ] **Step 3: 运行测试确认 RED**

```bash
flutter test test/core/models/startup_test.dart test/core/providers/startup_provider_test.dart test/features/search/search_history_store_test.dart
```

Expected: 缺少磁链热词属性、缓存键和 `storageKey` 参数导致编译失败。

- [ ] **Step 4: 实现模型、Provider 与缓存键**

```dart
const StartupData({
  this.backupDomainsData,
  this.recentKeywords = const [],
  this.recentMagnetKeywords = const [],
  this.settings,
  this.user,
});
final List<String> recentMagnetKeywords;
```

运行 `dart run build_runner build --delete-conflicting-outputs` 生成映射。Provider 增加不可变副本字段/getter，并在成功分支赋值。新增：

```dart
static const String magnetSearchHistory = 'key_magnet_search_history';

SearchHistoryStore(
  this._prefs, {
  this.storageKey = StorageKeys.searchHistory,
});
final String storageKey;
```

将 store 中固定缓存键全部替换为实例 `storageKey`。

- [ ] **Step 5: 重跑 Step 3 确认 GREEN**

- [ ] **Step 6: 提交**

```bash
git add lib/core/models/startup.dart lib/core/models/startup.g.dart lib/core/providers/startup_provider.dart lib/core/storage/storage_keys.dart lib/features/search/services/search_history_store.dart test/core/models/startup_test.dart test/core/providers/startup_provider_test.dart test/features/search/search_history_store_test.dart
git commit -m "feat: expose magnet search startup data"
```

---

### Task 2: 磁链排序与 API 数据源

**Files:**
- Create: `lib/features/search/models/magnet_search_sort.dart`
- Create: `lib/features/search/services/magnet_search_service.dart`
- Modify: `lib/core/network/endpoints.dart`
- Test: `test/features/search/magnet_search_service_test.dart`

**Interfaces:**
- Consumes: `ApiClient`、`apiMap/apiList/apiInt`、`normalizeMagnetJson`、`Magnet`。
- Produces: `MagnetSearchSort`、`MagnetSearchDataSource.getMagnets(...)`、`MagnetSearchService`。

- [ ] **Step 1: 写失败的排序和请求契约测试**

```dart
test('四种排序映射正确', () {
  expect(
    MagnetSearchSort.values.map((value) => value.apiValue),
    ['relevance', 'created', 'files', 'size'],
  );
  expect(
    MagnetSearchSort.values.map((value) => value.label),
    ['相关度', '时间', '文件数', '文件大小'],
  );
});
```

FakeAdapter 返回包含 `hash/name/size/files_count/created_at` 的磁链和 `current_page: 2`。调用 `created`、`fromRecent: true`、`page: 2` 后断言参数严格为：

```dart
{
  'q': '桥本香菜',
  'sort_by': 'created',
  'from_recent': 'true',
  'page': 2,
  'limit': 48,
}
```

再分别返回 48 条和 47 条，断言 `totalPages` 为 `currentPage + 1` 和 `currentPage`。

- [ ] **Step 2: 运行测试确认 RED**

```bash
flutter test test/features/search/magnet_search_service_test.dart
```

- [ ] **Step 3: 实现模型、端点和服务**

```dart
enum MagnetSearchSort {
  relevance('相关度', 'relevance'),
  created('时间', 'created'),
  files('文件数', 'files'),
  size('文件大小', 'size');

  const MagnetSearchSort(this.label, this.apiValue);
  final String label;
  final String apiValue;
}

abstract interface class MagnetSearchDataSource {
  Future<PagedResult<Magnet>> getMagnets({
    required String query,
    required MagnetSearchSort sort,
    required bool fromRecent,
    int page = 1,
  });
}
```

新增 `Endpoints.searchMagnet = '/api/v1/search_magnet'`。服务发送五个参数；`magnets` 依次经过 `normalizeMagnetJson` 和 `Magnet.fromJson`；用 48 条规则构造 `PagedResult`。

```dart
final response = await _api.get(
  Endpoints.searchMagnet,
  queryParameters: {
    'q': query,
    'sort_by': sort.apiValue,
    'from_recent': fromRecent.toString(),
    'page': page,
    'limit': pageSize,
  },
);
final data = apiMap(response.data);
final items = apiList(data, const ['magnets'])
    .map(normalizeMagnetJson)
    .map(Magnet.fromJson)
    .toList(growable: false);
final currentPage = apiInt(data['current_page'], page);
return PagedResult(
  items: items,
  currentPage: currentPage,
  totalPages: items.length >= pageSize ? currentPage + 1 : currentPage,
  total: apiInt(data['total_count'] ?? data['total'], items.length),
);
```

- [ ] **Step 4: 重跑 Step 2 确认 GREEN**

- [ ] **Step 5: 提交**

```bash
git add lib/core/network/endpoints.dart lib/features/search/models/magnet_search_sort.dart lib/features/search/services/magnet_search_service.dart test/features/search/magnet_search_service_test.dart
git commit -m "feat: add magnet search service"
```

---

### Task 3: 共享磁链列表项

**Files:**
- Create: `lib/core/widgets/magnet_list_tile.dart`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Create: `test/core/widgets/magnet_list_tile_test.dart`
- Test: `test/features/movie_detail/movie_detail_screen_test.dart`

**Interfaces:**
- Consumes: `Magnet`、Clipboard、当前详情页 `_MagnetTile`。
- Produces: `MagnetListTile({required Magnet magnet})`、`MagnetListDivider()`。

- [ ] **Step 1: 写失败的共享组件测试**

渲染含标题、1 MB、3 个文件、日期、高清/字幕的 Magnet，断言文本和图标。捕获 `Clipboard.setData`，点击后断言复制 `magnet:?xt=urn:btih:hash-1` 并显示“磁力链接已复制”。第二用例断言已有 `magnet:?` 时原样复制；分隔线 height 为 1、indent/endIndent 为 16。

- [ ] **Step 2: 运行测试确认 RED**

```bash
flutter test test/core/widgets/magnet_list_tile_test.dart
```

- [ ] **Step 3: 抽取当前详情页实现**

移动 URI 补全、剪贴板、Semantics、标题/徽标/元数据布局到 `MagnetListTile`。新增：

```dart
class MagnetListDivider extends StatelessWidget {
  const MagnetListDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}
```

详情页改用：

```dart
separatorBuilder: (_, _) => const MagnetListDivider(),
itemBuilder: (_, index) => MagnetListTile(magnet: magnets[index]),
```

删除私有 `_MagnetTile`；只有 `rg "_InfoBadge"` 确认无调用才删除私有 badge。

- [ ] **Step 4: 运行共享与详情回归**

```bash
flutter test test/core/widgets/magnet_list_tile_test.dart test/features/movie_detail/movie_detail_screen_test.dart
```

- [ ] **Step 5: 提交**

```bash
git add lib/core/widgets/magnet_list_tile.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/widgets/magnet_list_tile_test.dart test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "refactor: share magnet list tile"
```

---

### Task 4: 磁链搜索首页与路由

**Files:**
- Create: `lib/features/search/widgets/search_keyword_section.dart`
- Modify: `lib/features/search/screens/search_screen.dart`
- Create: `lib/features/search/screens/magnet_search_screen.dart`
- Create: `lib/features/search/screens/magnet_search_results_screen.dart`（先建立最终构造器的可编译壳）
- Modify: `lib/features/search/index.dart`
- Modify: `lib/core/router/routes.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/features/search/magnet_search_screen_test.dart`
- Test: `test/features/search/search_screen_test.dart`
- Test: `test/features/home/tofu_scroll_test.dart`
- Test: `test/app_router_test.dart`

**Interfaces:**
- Consumes: `StartupProvider.recentMagnetKeywords`、独立 `SearchHistoryStore`、豆腐块 `/search/magnet`。
- Produces: `SearchKeywordSection`、`MagnetSearchPage`、`AppRoutes.magnetSearchResults`、结果子路由。

- [ ] **Step 1: 写失败的首页行为测试**

注入磁链历史与热词，断言两模块。测试三种跳转参数：

```dart
// 历史
{'q': '历史磁链', 'from_recent': 'true'}
// 热词
{'q': '近期磁链', 'from_recent': 'false'}
// trim 后手输
{'q': '手输磁链', 'from_recent': 'false'}
```

清空时断言磁链历史消失，普通历史保持不变。

- [ ] **Step 2: 写失败的豆腐块与空查询路由测试**

注册并点击“找磁链”，断言 path 为 `AppRoutes.magnetSearch`。以空白 q 打开 `magnetSearchResults`，断言重定向父路由。运行：

```bash
flutter test test/features/search/magnet_search_screen_test.dart test/features/search/search_screen_test.dart test/features/home/tofu_scroll_test.dart test/app_router_test.dart
```

- [ ] **Step 3: 抽取共享关键词区块**

把 `_KeywordSection` 原样移为 `SearchKeywordSection`，保留标题样式、compact ActionChip、间距和 trailing。普通搜索改用它并先单独运行 `search_screen_test.dart`。

- [ ] **Step 4: 实现磁链搜索首页**

```dart
class MagnetSearchPage extends StatefulWidget {
  const MagnetSearchPage({
    super.key,
    this.historyStore,
    this.recentKeywords,
  });
  final SearchHistoryStore? historyStore;
  final List<String>? recentKeywords;
}
```

生产 store 使用 `StorageKeys.magnetSearchHistory`。跳转函数 trim 并保存关键词，URI 为：

```dart
Uri(
  path: AppRoutes.magnetSearchResults,
  queryParameters: {
    'q': keyword,
    'from_recent': fromRecent.toString(),
  },
)
```

手输/热词传 false，历史传 true；热词读取 `StartupProvider.recentMagnetKeywords`。

- [ ] **Step 5: 注册路由和结果页最终构造器**

新增 `AppRoutes.magnetSearchResults = '/search/magnet/results'`。替换占位路由并增加 `results` 子路由；空 q 重定向父路由，否则构建：

```dart
MagnetSearchResultsPage(
  key: state.pageKey,
  query: state.uri.queryParameters['q']!.trim(),
  fromRecent:
      state.uri.queryParameters['from_recent']?.toLowerCase() == 'true',
)
```

结果页壳声明最终参数 `query`、`fromRecent`、可选 `historyStore` 和 `dataSource`；Task 5 完成正文。

- [ ] **Step 6: 重跑 Step 2 确认 GREEN**

- [ ] **Step 7: 提交**

```bash
git add lib/features/search/widgets/search_keyword_section.dart lib/features/search/screens/search_screen.dart lib/features/search/screens/magnet_search_screen.dart lib/features/search/screens/magnet_search_results_screen.dart lib/features/search/index.dart lib/core/router/routes.dart lib/core/router/app_router.dart test/features/search/magnet_search_screen_test.dart test/features/search/search_screen_test.dart test/features/home/tofu_scroll_test.dart test/app_router_test.dart
git commit -m "feat: add magnet search landing page"
```

---

### Task 5: 排序与无限分页结果页

**Files:**
- Modify: `lib/features/search/screens/magnet_search_results_screen.dart`
- Create: `test/features/search/magnet_search_results_screen_test.dart`

**Interfaces:**
- Consumes: `MagnetSearchDataSource`、`MagnetSearchSort`、`PaginationController<Magnet>`、`SortSegmented`、共享磁链组件与独立历史。
- Produces: 完整 `MagnetSearchResultsPage({query, fromRecent, historyStore?, dataSource?})`。

- [ ] **Step 1: 写失败的首屏和排序测试**

创建记录 `query/sort/fromRecent/page` 的 fake。初次 pump 断言 relevance/page 1/fromRecent。检查：

```dart
final segmented = tester.widget<SegmentedButton<MagnetSearchSort>>(
  find.byType(SegmentedButton<MagnetSearchSort>),
);
expect(segmented.showSelectedIcon, isFalse);
expect(segmented.expandedInsets, EdgeInsets.zero);
expect(segmented.style?.visualDensity, VisualDensity.compact);
```

断言四个文案；点击“时间”后断言新调用为 created/page 1，旧行被替换。

- [ ] **Step 2: 写失败的分页与状态测试**

第一页 fake 返回 `totalPages: 2` 和足够多行；拖动 key `magnet-results-list` 后断言页码调用为 [1,2] 且第二页出现。使用 Completer/throwing fake 分别断言：

- 首屏等待显示进度条；
- 空页显示“未找到相关磁链”；
- 首屏失败显示“磁链搜索失败”并可重试；
- 第 2 页失败保留第一页并显示 key `magnet-load-more-retry`；
- 点击追加重试再次请求第 2 页；
- 点击结果复制磁链；
- 重新搜索保存独立历史并以 `from_recent=false` 替换结果路由。

- [ ] **Step 3: 运行测试确认 RED**

```bash
flutter test test/features/search/magnet_search_results_screen_test.dart
```

- [ ] **Step 4: 实现排序和 generation-safe 分页**

创建 `PaginationController<Magnet>(fetch: _fetchPage)..fetchMore()`，默认 relevance。排序变化时忽略重复值，否则 setState 后 `reloadWith(_fetchPage)`。排序区严格使用：

```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  child: SortSegmented<MagnetSearchSort>(
    key: const Key('magnet-sort-filter'),
    compact: true,
    expanded: true,
    options: [
      for (final sort in MagnetSearchSort.values)
        (label: sort.label, value: sort),
    ],
    value: _sort,
    onChanged: _changeSort,
  ),
)
```

- [ ] **Step 5: 实现懒列表与错误状态**

`ListenableBuilder` 监听 controller。`ScrollEndNotification` 且 `extentAfter < 200`、hasMore、无 error 时 fetchMore。`ListView.separated` 使用 key `magnet-results-list`、`MagnetListTile`、`MagnetListDivider`。加载 footer 显示进度条；追加失败显示：

```dart
TextButton.icon(
  key: const Key('magnet-load-more-retry'),
  onPressed: _controller.fetchMore,
  icon: const Icon(Icons.refresh),
  label: const Text('加载失败，点击重试'),
)
```

首屏失败用 `ErrorRetryWidget(message: '磁链搜索失败', onRetry: _controller.refresh)`；空列表显示可滚动的“未找到相关磁链”。dispose pagination/text controller。重新搜索先写磁链历史，再 `context.pushReplacement` 到 `from_recent=false` 的新结果 URI。

- [ ] **Step 6: 运行测试确认 GREEN**

```bash
flutter test test/features/search/magnet_search_results_screen_test.dart test/core/widgets/magnet_list_tile_test.dart
```

- [ ] **Step 7: 提交**

```bash
git add lib/features/search/screens/magnet_search_results_screen.dart test/features/search/magnet_search_results_screen_test.dart
git commit -m "feat: add paged magnet search results"
```

---

### Task 6: 回归与最终验证

**Files:**
- Modify: 仅在聚焦测试暴露需求范围内缺陷时修改对应文件。
- Verify: Tasks 1-5 全部文件。

**Interfaces:**
- Consumes: 完整磁链搜索流程。
- Produces: 已格式化、通过分析与回归检查、无未提交任务文件的实现。

- [ ] **Step 1: 格式化触及文件**

```bash
dart format lib/core/models/startup.dart lib/core/models/startup.g.dart lib/core/providers/startup_provider.dart lib/core/storage/storage_keys.dart lib/core/network/endpoints.dart lib/core/widgets/magnet_list_tile.dart lib/core/router/routes.dart lib/core/router/app_router.dart lib/features/movie_detail/screens/movie_detail_screen.dart lib/features/search/models/magnet_search_sort.dart lib/features/search/services/search_history_store.dart lib/features/search/services/magnet_search_service.dart lib/features/search/widgets/search_keyword_section.dart lib/features/search/screens/search_screen.dart lib/features/search/screens/magnet_search_screen.dart lib/features/search/screens/magnet_search_results_screen.dart lib/features/search/index.dart test/core/models/startup_test.dart test/core/providers/startup_provider_test.dart test/core/widgets/magnet_list_tile_test.dart test/features/search/search_history_store_test.dart test/features/search/magnet_search_service_test.dart test/features/search/magnet_search_screen_test.dart test/features/search/magnet_search_results_screen_test.dart test/features/search/search_screen_test.dart test/features/home/tofu_scroll_test.dart test/features/movie_detail/movie_detail_screen_test.dart test/app_router_test.dart
```

- [ ] **Step 2: 运行聚焦测试**

```bash
flutter test test/core/models/startup_test.dart test/core/providers/startup_provider_test.dart test/core/widgets/magnet_list_tile_test.dart test/features/search/search_history_store_test.dart test/features/search/magnet_search_service_test.dart test/features/search/magnet_search_screen_test.dart test/features/search/magnet_search_results_screen_test.dart test/features/search/search_screen_test.dart test/features/home/tofu_scroll_test.dart test/features/movie_detail/movie_detail_screen_test.dart test/app_router_test.dart
```

Expected: 全部通过。

- [ ] **Step 3: 运行全量测试**

```bash
flutter test
```

Expected: 全部通过。如有无关既有失败，记录文件、用例名和错误，重跑聚焦套件且不宣称全量通过。

- [ ] **Step 4: 运行静态分析与差异检查**

```bash
flutter analyze
git diff --check
git status --short --branch
```

Expected: analyze 为 “No issues found!”，diff check 无输出，status 无未提交任务文件。

- [ ] **Step 5: 如验证产生需求内修正则提交**

```bash
git commit -m "fix: complete magnet search regressions"
```

仅暂存验证修正涉及的文件；没有修正时不创建空提交。
