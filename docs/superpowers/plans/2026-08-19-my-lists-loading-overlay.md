# 我的清单：编辑/删除 Loading 蒙版实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 给「我的清单」页的编辑（改名）与删除操作添加全屏 loading 蒙版，请求进行中禁止一切交互。

**架构：** `_MyListsPageState` 新增 `_busy` 状态，`body` 改为 `Stack` 叠加全屏半透明遮罩 + 居中转圈；`_renameList`/`_deleteList` 在确认弹窗关闭后置 `_busy = true`，`try/finally` 保证成功/失败都复位。

**技术栈：** Flutter / Dart 3.8、flutter_test（widget 测试）

**规格：** `docs/superpowers/specs/2026-08-19-my-lists-loading-overlay-design.md`

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/features/profile/screens/my_lists_page.dart` | 修改：`_busy` 状态 + `Stack` 蒙版 + 流程包裹 |
| `test/features/profile/my_lists_page_test.dart` | 修改：fake 加可控延迟（Completer）+ 蒙版测试用例 |

---

### 任务 1：实现 loading 蒙版

**文件：**
- 修改：`lib/features/profile/screens/my_lists_page.dart`
- 修改：`test/features/profile/my_lists_page_test.dart`

- [ ] **步骤 1：扩展 fake 支持可控延迟（测试前置）**

`test/features/profile/my_lists_page_test.dart` 的 `_FakeUserListsDataSource` 增加延迟门闩：

```dart
  /// 置非 null 后，rename/delete 会等待该 Completer 完成才继续（模拟请求中）。
  Completer<void>? renameGate;
  Completer<void>? deleteGate;

  @override
  Future<void> renameList({required String id, required String name}) async {
    final gate = renameGate;
    if (gate != null) await gate.future;
    if (failRename) throw StateError('rename failed');
    renamed.add((id: id, name: name));
    final index = lists.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final old = lists[index];
    lists[index] = ListModel(
      id: old.id,
      name: name,
      movieCount: old.movieCount,
      viewedCount: old.viewedCount,
      hasMovie: old.hasMovie,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> deleteList(String id) async {
    final gate = deleteGate;
    if (gate != null) await gate.future;
    if (failDelete) throw StateError('delete failed');
    deleted.add(id);
    lists.removeWhere((item) => item.id == id);
  }
```

顶部 import 增加 `dart:async`：

```dart
import 'dart:async';
```

- [ ] **步骤 2：编写失败的蒙版测试**

在 `test/features/profile/my_lists_page_test.dart` 的 `main()` 中追加 4 个用例：

```dart
  testWidgets('删除请求进行中显示蒙版且列表不可交互', (tester) async {
    final source = await _pumpPage(tester);
    source.deleteGate = Completer<void>();

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定删除'));
    await tester.pump();

    // 请求进行中：蒙版 + 转圈可见
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == const Color(0x73000000),
      ),
      findsOneWidget,
    );
    // 蒙版拦截：点击排序按钮无效（蒙版挡住）
    await tester.tap(
      find.byKey(const Key('my-lists-sort-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(source.sortRequests, ['updated_at']);

    // 完成请求 → 蒙版消失
    source.deleteGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(source.deleted, ['l1']);
  });

  testWidgets('编辑请求进行中显示蒙版', (tester) async {
    final source = await _pumpPage(tester);
    source.renameGate = Completer<void>();

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新片单名');
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    source.renameGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(source.renamed, [(id: 'l1', name: '新片单名')]);
  });

  testWidgets('删除失败时蒙版消失且提示错误', (tester) async {
    final source = await _pumpPage(tester);
    source.failDelete = true;

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定删除'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('删除失败'), findsOneWidget);
    expect(find.text('收藏精选'), findsOneWidget);
  });

  testWidgets('编辑失败时蒙版消失且提示错误', (tester) async {
    final source = await _pumpPage(tester);
    source.failRename = true;

    await tester.drag(find.text('收藏精选'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新片单名');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('重命名失败'), findsOneWidget);
    expect(find.text('收藏精选'), findsOneWidget);
  });
```

- [ ] **步骤 3：运行测试验证失败**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter test test/features/profile/my_lists_page_test.dart
```

预期：新增用例失败（`CircularProgressIndicator` 找不到——当前无蒙版）；既有用例（8 个）通过。

- [ ] **步骤 4：实现蒙版**

`lib/features/profile/screens/my_lists_page.dart`：

1. State 增加 `_busy`：

```dart
  late final UserListsDataSource _dataSource;
  late final PaginationController<ListModel> _controller;
  var _sortBy = _sortByUpdatedAt;
  var _busy = false;
```

2. `_renameList` 确认后包裹 `_busy`（try/finally）：

```dart
  Future<void> _renameList(ListModel list) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameListDialog(initialName: list.name),
    );
    if (newName == null || newName.isEmpty || newName == list.name) return;
    setState(() => _busy = true);
    try {
      try {
        await _dataSource.renameList(id: list.id, name: newName);
      } catch (error, stackTrace) {
        developer.log(
          '重命名清单失败',
          name: 'my-lists',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted) return;
        _showMessage('重命名失败');
        return;
      }
      if (!mounted) return;
      // 服务器为准：重载第一页，同时清掉分页状态与残留错误。
      // refresh 内部已捕获 GET 错误（存入 _error，由列表重试按钮兜底），
      // 重命名已成功，不能再误报「重命名失败」。
      await _controller.refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
```

3. `_deleteList` 同样包裹：

```dart
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
    setState(() => _busy = true);
    try {
      try {
        await _dataSource.deleteList(list.id);
      } catch (error, stackTrace) {
        developer.log(
          '删除清单失败',
          name: 'my-lists',
          error: error,
          stackTrace: stackTrace,
        );
        if (!mounted) return;
        _showMessage('删除失败');
        return;
      }
      if (!mounted) return;
      // 服务器为准：重载第一页，同时清掉分页状态与残留错误。
      // refresh 内部已捕获 GET 错误（存入 _error，由列表重试按钮兜底），
      // 删除已成功，不能再误报「删除失败」。
      await _controller.refresh();
      if (!mounted) return;
      _showMessage('清单已删除');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
```

4. `build` 的 `body` 改为 `Stack` 叠加蒙版：

```dart
      body: Stack(
        children: [
          PaginatedListView<ListModel>(
            controller: _controller,
            emptyMessage: '暂无清单',
            itemBuilder: (context, list) => Slidable(
              key: ValueKey('slidable-${list.id}'),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => unawaited(_renameList(list)),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x73000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
```

- [ ] **步骤 5：运行测试验证通过**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter test test/features/profile/my_lists_page_test.dart
```

预期：12 个测试全部通过（原 8 + 新 4）。

- [ ] **步骤 6：回归验证**

```bash
cd /Users/luxcis/data/workspace/Flutter/Jdb_Flutter
flutter test test/features/profile
flutter analyze
```

预期：profile 测试全部通过；`No issues found!`。

- [ ] **步骤 7：Commit**

```bash
git add lib/features/profile/screens/my_lists_page.dart test/features/profile/my_lists_page_test.dart
git commit -m "feat(profile): show loading overlay during list edit/delete"
```

---

## 自检

**规格覆盖度：**
- ✅ `_busy` 状态 → 任务 1 步骤 4.1
- ✅ `Stack` 蒙版（ColoredBox 拦截 + 居中转圈）→ 任务 1 步骤 4.4
- ✅ 编辑/删除确认后置 `_busy = true`、`try/finally` 复位 → 任务 1 步骤 4.2/4.3
- ✅ 失败路径蒙版消失 + SnackBar → 任务 1 步骤 4（finally 复位）+ 步骤 2 测试
- ✅ fake 可控延迟（Completer）→ 任务 1 步骤 1
- ✅ 测试覆盖（请求中蒙版可见、完成后消失、失败路径）→ 任务 1 步骤 2

**占位符扫描：** 无 TODO / 待定；每个代码步骤完整。

**类型一致性：** `_busy` 在实现（步骤 4）与测试（步骤 2 断言 CircularProgressIndicator）中一致；`renameGate`/`deleteGate` 在 fake（步骤 1）与测试（步骤 2）中一致；蒙版颜色 `Color(0x73000000)` 在实现（步骤 4.4）与测试（步骤 2 断言）中一致。
