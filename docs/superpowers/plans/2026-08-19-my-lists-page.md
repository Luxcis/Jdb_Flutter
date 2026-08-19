# 「我的清单」页面实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现「我的-我的清单」页面：清单列表（分页 + 排序切换）+ 左滑编辑/删除 + 点击进入清单影片列表（复用 CommonListPage）。

**架构：** profile feature 内新增 `UserListsService`（数据源接口 + API 实现 + 不可用实现），页面用 `PaginationController` + `PaginatedListView` 渲染，`flutter_slidable` 提供左滑操作，`ListModel` 扩展 `createdAt`，`ApiClient` 新增 `put`。

**技术栈：** Flutter / Dart 3.8、dio、go_router、provider、flutter_slidable ^4.0.3、json_serializable（build_runner）

**规格：** `docs/superpowers/specs/2026-08-19-my-lists-page-design.md`

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/core/network/api_client.dart` | 修改：新增 `put` 方法 |
| `lib/core/models/list_model.dart` | 修改：新增 `createdAt` 字段 |
| `lib/core/models/list_model.g.dart` | 修改：build_runner 重新生成 |
| `lib/features/profile/services/user_lists_service.dart` | 创建：数据源接口 + `UserListsService` + `UnavailableUserListsDataSource` |
| `lib/features/profile/screens/my_lists_page.dart` | 创建：页面（排序切换、左滑编辑/删除、跳转清单影片列表） |
| `lib/features/profile/index.dart` | 修改：export 新页面 |
| `lib/core/router/app_router.dart` | 修改：`/profile/lists` 路由替换为 `MyListsPage` |
| `pubspec.yaml` | 修改：新增 `flutter_slidable` |
| `test/features/profile/user_lists_service_test.dart` | 创建：service 单测 |
| `test/features/profile/my_lists_page_test.dart` | 创建：页面 widget 测试 |

---

### 任务 1：添加 flutter_slidable 依赖

**文件：**
- 修改：`pubspec.yaml`

- [ ] **步骤 1：添加依赖**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter pub add flutter_slidable
```

预期：`pubspec.yaml` 的 `dependencies` 中出现 `flutter_slidable: ^4.0.3`，`pubspec.lock` 更新。

- [ ] **步骤 2：验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
grep -n "flutter_slidable" pubspec.yaml
```

预期：输出版本行。

- [ ] **步骤 3：Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add flutter_slidable dependency"
```

---

### 任务 2：ApiClient 新增 put 方法

**文件：**
- 修改：`lib/core/network/api_client.dart`（在 `post` 方法后、`delete` 方法前插入）

- [ ] **步骤 1：添加 put 方法**

在 `lib/core/network/api_client.dart` 的 `post` 方法（约 68-70 行）与 `delete` 方法之间插入：

```dart
  /// Sends a PUT request through the configured Dio client.
  Future<Response> put(String path, {dynamic data}) {
    return dio.put(path, data: data);
  }
```

- [ ] **步骤 2：验证编译**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter analyze lib/core/network/api_client.dart
```

预期：`No issues found!`（若 analyze 输出 SDK cache 噪音，以 `No issues found` 为准）。

- [ ] **步骤 3：Commit**

```bash
git add lib/core/network/api_client.dart
git commit -m "feat(network): add put method to ApiClient"
```

---

### 任务 3：ListModel 增加 createdAt 字段

**文件：**
- 修改：`lib/core/models/list_model.dart`
- 修改：`lib/core/models/list_model.g.dart`（由 build_runner 生成）

- [ ] **步骤 1：修改模型**

`lib/core/models/list_model.dart`：构造函数增加 `this.createdAt`，字段声明，`copyWith` 增加透传：

```dart
  const ListModel({
    required this.id,
    required this.name,
    this.movieCount = 0,
    this.viewedCount = 0,
    this.hasMovie = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final int movieCount;
  final int viewedCount;
  final bool hasMovie;

  /// 创建时间（来自 `created_at`），可能为 null。
  final String? createdAt;

  ListModel copyWith({int? movieCount, bool? hasMovie}) {
    return ListModel(
      id: id,
      name: name,
      movieCount: movieCount ?? this.movieCount,
      viewedCount: viewedCount,
      hasMovie: hasMovie ?? this.hasMovie,
      createdAt: createdAt,
    );
  }
```

- [ ] **步骤 2：重新生成 .g.dart**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
dart run build_runner build --delete-conflicting-outputs
```

预期：`list_model.g.dart` 的 `_$ListModelFromJson` 中新增 `createdAt: json['created_at'] as String?`。

- [ ] **步骤 3：验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
grep -n "created_at" lib/core/models/list_model.g.dart
```

预期：`createdAt: json['created_at'] as String?`。

- [ ] **步骤 4：Commit**

```bash
git add lib/core/models/list_model.dart lib/core/models/list_model.g.dart
git commit -m "feat(models): add createdAt to ListModel"
```

---

### 任务 4：UserListsService 数据层

**文件：**
- 创建：`lib/features/profile/services/user_lists_service.dart`
- 测试：`test/features/profile/user_lists_service_test.dart`

- [ ] **步骤 1：编写失败的测试**

创建 `test/features/profile/user_lists_service_test.dart`：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/features/profile/services/user_lists_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({FakeAdapter adapter, UserListsService service})>
buildUserListsFixture() async {
  final preferences = await SharedPreferences.getInstance();
  final domainManager = await DomainManager.load(preferences);
  final adapter = FakeAdapter();
  final dio = Dio(BaseOptions(baseUrl: domainManager.currentUrl))
    ..httpClientAdapter = adapter
    ..interceptors.add(ResponseInterceptor(onAuthError: () {}));
  final api = ApiClient.forTest(dio: dio, domainManager: domainManager);
  return (adapter: adapter, service: UserListsService(api));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('getMyLists 发送 sort_by 必填参数并解析 lists 分页', () async {
    final fixture = await buildUserListsFixture();
    fixture.adapter.enqueue(Endpoints.lists, {
      'success': 1,
      'data': {
        'lists': [
          {
            'id': 'l1',
            'name': '我的收藏',
            'movies_count': 12,
            'views_count': 34,
            'created_at': '2026-08-01 10:00:00',
          },
        ],
        'current_page': 1,
        'total_pages': 2,
        'total': 25,
      },
    });

    final result = await fixture.service.getMyLists(sortBy: 'updated_at');

    expect(result.items.single.id, 'l1');
    expect(result.items.single.name, '我的收藏');
    expect(result.items.single.movieCount, 12);
    expect(result.items.single.viewedCount, 34);
    expect(result.items.single.createdAt, '2026-08-01 10:00:00');
    expect(result.currentPage, 1);
    expect(result.totalPages, 2);
    expect(fixture.adapter.requests.single.queryParameters, {
      'sort_by': 'updated_at',
      'page': 1,
      'limit': 48,
    });
  });

  test('renameList 发送 PUT 到 /api/v1/lists/{id} body 为 JSON name', () async {
    final fixture = await buildUserListsFixture();
    fixture.adapter.enqueue('${Endpoints.lists}/l1', {
      'success': 1,
      'data': null,
    });

    await fixture.service.renameList(id: 'l1', name: '新名称');

    final request = fixture.adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '${Endpoints.lists}/l1');
    expect(request.data, {'name': '新名称'});
  });

  test('deleteList 发送 DELETE 到 /api/v1/lists/{id}', () async {
    final fixture = await buildUserListsFixture();
    fixture.adapter.enqueue('${Endpoints.lists}/l1', {
      'success': 1,
      'data': null,
    });

    await fixture.service.deleteList('l1');

    final request = fixture.adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '${Endpoints.lists}/l1');
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter test test/features/profile/user_lists_service_test.dart
```

预期：编译失败，`UserListsService` / `UserListsDataSource` 未定义。

- [ ] **步骤 3：实现服务**

创建 `lib/features/profile/services/user_lists_service.dart`：

```dart
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_data.dart';
import 'package:jade/core/network/endpoints.dart';

/// 「我的清单」数据源抽象，便于测试注入与 API 不可用时降级。
abstract interface class UserListsDataSource {
  Future<PagedResult<ListModel>> getMyLists({
    required String sortBy,
    int page = 1,
  });

  Future<void> renameList({required String id, required String name});

  Future<void> deleteList(String id);
}

/// 默认 API 实现。全部接口需 BearerAuth（由 ApiClient 拦截器注入）。
class UserListsService implements UserListsDataSource {
  UserListsService(this._api);

  static const _pageSize = 48;

  final ApiClient _api;

  @override
  Future<PagedResult<ListModel>> getMyLists({
    required String sortBy,
    int page = 1,
  }) async {
    final response = await _api.get(
      Endpoints.lists,
      queryParameters: {'sort_by': sortBy, 'page': page, 'limit': _pageSize},
    );
    return apiPageResult(
      response.data,
      keys: const ['lists', 'items'],
      page: page,
      pageSize: _pageSize,
      fromJson: (json) => ListModel.fromJson(normalizeListModelJson(json)),
    );
  }

  @override
  Future<void> renameList({required String id, required String name}) async {
    await _api.put('${Endpoints.lists}/$id', data: {'name': name});
  }

  @override
  Future<void> deleteList(String id) async {
    await _api.delete('${Endpoints.lists}/$id');
  }
}

/// ApiClient 未初始化时的空实现（页面数据源注入缺省值）。
class UnavailableUserListsDataSource implements UserListsDataSource {
  const UnavailableUserListsDataSource();

  @override
  Future<PagedResult<ListModel>> getMyLists({
    required String sortBy,
    int page = 1,
  }) async => PagedResult(
    items: const [],
    currentPage: page,
    totalPages: page,
    total: 0,
  );

  @override
  Future<void> renameList({required String id, required String name}) async {}

  @override
  Future<void> deleteList(String id) async {}
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter test test/features/profile/user_lists_service_test.dart
```

预期：3 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add lib/features/profile/services/user_lists_service.dart test/features/profile/user_lists_service_test.dart
git commit -m "feat(profile): add user lists service with get/rename/delete"
```

---

### 任务 5：MyListsPage 页面

**文件：**
- 创建：`lib/features/profile/screens/my_lists_page.dart`
- 修改：`lib/features/profile/index.dart`
- 测试：`test/features/profile/my_lists_page_test.dart`

- [ ] **步骤 1：编写失败的测试**

创建 `test/features/profile/my_lists_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/features/profile/screens/my_lists_page.dart';
import 'package:jade/features/profile/services/user_lists_service.dart';

class _FakeUserListsDataSource implements UserListsDataSource {
  _FakeUserListsDataSource({this.lists = const []});

  final List<ListModel> lists;
  final sortRequests = <String>[];
  final renamed = <({String id, String name})>[];
  final deleted = <String>[];
  var failRename = false;
  var failDelete = false;

  @override
  Future<PagedResult<ListModel>> getMyLists({
    required String sortBy,
    int page = 1,
  }) async {
    sortRequests.add(sortBy);
    return PagedResult(
      items: lists,
      currentPage: page,
      totalPages: 1,
      total: lists.length,
    );
  }

  @override
  Future<void> renameList({required String id, required String name}) async {
    if (failRename) throw StateError('rename failed');
    renamed.add((id: id, name: name));
  }

  @override
  Future<void> deleteList(String id) async {
    if (failDelete) throw StateError('delete failed');
    deleted.add(id);
  }
}

List<ListModel> _sampleLists() => [
  ListModel(id: 'l1', name: '收藏精选', movieCount: 3, viewedCount: 10),
  ListModel(id: 'l2', name: '待看片单', movieCount: 5, viewedCount: 20),
];

Future<_FakeUserListsDataSource> _pumpPage(
  WidgetTester tester, {
  List<ListModel>? lists,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source = _FakeUserListsDataSource(lists: lists ?? _sampleLists());
  await tester.pumpWidget(
    MaterialApp(
      home: MyListsPage(dataSource: source),
    ),
  );
  await tester.pumpAndSettle();
  return source;
}

void main() {
  testWidgets('初始加载显示清单列表且默认按更新时间排序', (tester) async {
    final source = await _pumpPage(tester);

    expect(find.text('我的清单'), findsOneWidget);
    expect(find.text('收藏精选'), findsOneWidget);
    expect(find.text('待看片单'), findsOneWidget);
    expect(find.text('3 部影片，被查看 10 次'), findsOneWidget);
    expect(source.sortRequests, ['updated_at']);
  });

  testWidgets('点击排序图标切换为创建时间并重新请求', (tester) async {
    final source = await _pumpPage(tester);

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();

    expect(source.sortRequests, ['updated_at', 'created_at']);
  });

  testWidgets('左滑出现编辑和删除操作', (tester) async {
    await _pumpPage(tester);

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('编辑改名成功更新列表项名称', (tester) async {
    final source = await _pumpPage(tester);

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '新片单名');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(source.renamed, [(id: 'l1', name: '新片单名')]);
    expect(find.text('新片单名'), findsOneWidget);
    expect(find.text('收藏精选'), findsNothing);
  });

  testWidgets('删除确认后移除条目，取消则保留', (tester) async {
    final source = await _pumpPage(tester);

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('删除清单？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.deleted, isEmpty);
    expect(find.text('收藏精选'), findsOneWidget);

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定删除'));
    await tester.pumpAndSettle();

    expect(source.deleted, ['l1']);
    expect(find.text('收藏精选'), findsNothing);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter test test/features/profile/my_lists_page_test.dart
```

预期：编译失败，`MyListsPage` 未定义。

- [ ] **步骤 3：实现页面**

创建 `lib/features/profile/screens/my_lists_page.dart`：

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/list_summary_tile.dart';
import 'package:jade/core/widgets/paginated_list_view.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/common/screens/common_list_page.dart';
import 'package:jade/features/profile/services/user_lists_service.dart';

/// 「我的-我的清单」页：分页清单列表，支持排序切换与左滑编辑/删除。
class MyListsPage extends StatefulWidget {
  const MyListsPage({super.key, this.dataSource});

  final UserListsDataSource? dataSource;

  @override
  State<MyListsPage> createState() => _MyListsPageState();
}

class _MyListsPageState extends State<MyListsPage> {
  static const _sortByUpdatedAt = 'updated_at';
  static const _sortByCreatedAt = 'created_at';

  late final UserListsDataSource _dataSource;
  late final PaginationController<ListModel> _controller;
  var _sortBy = _sortByUpdatedAt;

  @override
  void initState() {
    super.initState();
    final api = ApiClient.instanceOrNull;
    _dataSource =
        widget.dataSource ??
        (api == null
            ? const UnavailableUserListsDataSource()
            : UserListsService(api));
    _controller = PaginationController<ListModel>(fetch: _fetchPage)
      ..fetchMore();
  }

  Future<PagedResult<ListModel>> _fetchPage(int page) =>
      _dataSource.getMyLists(sortBy: _sortBy, page: page);

  void _toggleSort() {
    setState(() {
      _sortBy =
          _sortBy == _sortByUpdatedAt ? _sortByCreatedAt : _sortByUpdatedAt;
    });
    _controller.reloadWith(_fetchPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _renameList(ListModel list) async {
    final controller = TextEditingController(text: list.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑清单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '清单名称'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == list.name) return;
    try {
      await _dataSource.renameList(id: list.id, name: newName);
      if (!mounted) return;
      final index = _controller.items.indexWhere((item) => item.id == list.id);
      if (index >= 0) {
        final items = List<ListModel>.of(_controller.items);
        items[index] = ListModel(
          id: list.id,
          name: newName,
          movieCount: list.movieCount,
          viewedCount: list.viewedCount,
          hasMovie: list.hasMovie,
          createdAt: list.createdAt,
        );
        _controller.replaceItems(items);
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('重命名失败');
    }
  }

  Future<void> _deleteList(ListModel list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除清单？'),
        content: Text('确定删除清单「${list.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dataSource.deleteList(list.id);
      if (!mounted) return;
      final items = _controller.items
          .where((item) => item.id != list.id)
          .toList();
      _controller.replaceItems(items);
      _showMessage('清单已删除');
    } catch (_) {
      if (!mounted) return;
      _showMessage('删除失败');
    }
  }

  void _openListMovies(ListModel list) {
    context.push(
      Uri(
        path: AppRoutes.commonList,
        queryParameters: {
          'title': '清单 - ${list.name}',
          'type': '0',
          'category': 'l',
          'id': list.id,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortLabel =
        _sortBy == _sortByUpdatedAt ? '更新时间' : '创建时间';
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的清单'),
        actions: [
          IconButton(
            key: const Key('my-lists-sort-button'),
            tooltip: '排序：$sortLabel',
            onPressed: _toggleSort,
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: PaginatedListView<ListModel>(
        controller: _controller,
        emptyMessage: '暂无清单',
        itemBuilder: (context, list) => Slidable(
          key: ValueKey('slidable-${list.id}'),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => unawaited(_renameList(list)),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                icon: Icons.edit_outlined,
                label: '编辑',
              ),
              SlidableAction(
                onPressed: (_) => unawaited(_deleteList(list)),
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                icon: Icons.delete_outline,
                label: '删除',
              ),
            ],
          ),
          child: ListSummaryTile(
            list: list,
            onTap: () => _openListMovies(list),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **步骤 4：给 PaginationController 增加 replaceItems**

修改 `lib/core/widgets/pagination_controller.dart`，在 `reshuffle` 方法后新增一个方法：

```dart
  /// 用 [items] 整体替换当前条目（保留分页状态）。
  void replaceItems(List<T> items) {
    _items
      ..clear()
      ..addAll(items);
    notifyListeners();
  }
```

- [ ] **步骤 5：export 新页面**

修改 `lib/features/profile/index.dart`：

```dart
export 'screens/my_lists_page.dart';
```

- [ ] **步骤 6：运行测试验证通过**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter test test/features/profile/my_lists_page_test.dart
```

预期：6 个测试全部通过。

- [ ] **步骤 7：Commit**

```bash
git add lib/features/profile/screens/my_lists_page.dart lib/features/profile/index.dart lib/core/widgets/pagination_controller.dart test/features/profile/my_lists_page_test.dart
git commit -m "feat(profile): add my lists page with swipe edit/delete"
```

---

### 任务 6：路由接线

**文件：**
- 修改：`lib/core/router/app_router.dart:310-316`

- [ ] **步骤 1：替换路由**

`lib/core/router/app_router.dart` 中 `/profile/lists` 路由的 child 从
`const ProfileNamedCollectionPage(title: '我的清单')` 替换为
`const MyListsPage()`（import 已由 `features/profile/index.dart` 的 export 提供）：

```dart
    GoRoute(
      path: AppRoutes.profileLists,
      builder: (c, s) => _AuthGuard(
        route: AppRoutes.profileLists,
        child: const MyListsPage(),
      ),
    ),
```

- [ ] **步骤 2：验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter analyze lib/core/router/app_router.dart lib/features/profile
```

预期：`No issues found!`。

- [ ] **步骤 3：Commit**

```bash
git add lib/core/router/app_router.dart
git commit -m "feat(router): wire my lists page to /profile/lists"
```

---

### 任务 7：全量验证

- [ ] **步骤 1：运行相关测试**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter test test/features/profile test/core/widgets/pagination_controller_test.dart test/core/widgets/paginated_list_view_test.dart
```

预期：全部通过（含既有 profile 测试，确认 `ProfileNamedCollectionPage` 移除
`我的清单` 用法未破坏其它测试——收藏类占位页仍使用该类）。

- [ ] **步骤 2：全量 analyze**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter analyze
```

预期：`No issues found!`（或与改动无关的既有告警）。

- [ ] **步骤 3：运行全量测试（可选但推荐）**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter test
```

预期：全部通过。

---

## 自检

**规格覆盖度：**
- ✅ GET /api/v1/lists 分页 + sort_by → 任务 4（getMyLists）+ 任务 5（排序切换）
- ✅ PUT 更新名称 → 任务 4（renameList）+ 任务 5（编辑弹窗）
- ✅ DELETE 删除 → 任务 4（deleteList）+ 任务 5（删除确认）
- ✅ 列表页样式同搜索-清单（ListSummaryTile）→ 任务 5
- ✅ 点击清单 → 清单影片列表（CommonListPage，category 'l'）→ 任务 5 `_openListMovies`
- ✅ 左滑编辑/删除 → 任务 5（flutter_slidable）
- ✅ 导航条右侧排序按钮切换更新时间/创建时间 → 任务 5（Icons.sort + _toggleSort）
- ✅ 路由 /profile/lists → 任务 6

**占位符扫描：** 无 TODO / 待定 / 概括性描述；每个代码步骤都有完整代码块。

**类型一致性：** `UserListsDataSource.getMyLists({required String sortBy, int page = 1})`、
`renameList({required String id, required String name})`、`deleteList(String id)`
在测试（任务 4 步骤 1 / 任务 5 步骤 1）与实现（任务 4 步骤 3 / 任务 5 步骤 3）
中签名一致。`PaginationController.replaceItems` 在任务 5 步骤 3 调用、步骤 4 定义，
签名匹配。`ListModel.createdAt` 在任务 3 定义，任务 4/5 使用。删除确认按钮文本为
「确定删除」，与 SlidableAction 的「删除」label 不同，测试 finder 无歧义。
