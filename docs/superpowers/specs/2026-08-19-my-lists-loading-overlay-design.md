# 我的清单：编辑/删除操作 Loading 蒙版设计

## 背景

「我的清单」页（`MyListsPage`）的编辑（改名）与删除操作在请求进行中
没有交互拦截：用户可能在请求完成前重复点击左滑操作、排序或列表项，
造成重复请求或误触。本设计为这两个操作添加全屏 loading 蒙版，
请求进行中禁止一切交互。

## 方案

### 页面状态

`_MyListsPageState` 新增 `bool _busy = false`，表示是否有进行中的
编辑/删除请求。

### 蒙版实现

`body` 改为 `Stack`，在列表之上叠加全屏半透明遮罩 + 居中转圈：

```dart
body: Stack(
  children: [
    PaginatedListView<ListModel>(...),  // 原有列表
    if (_busy)
      const Positioned.fill(
        child: ColoredBox(
          color: Colors.black45,  // 半透明遮罩，吞掉一切触摸事件
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
  ],
)
```

- `ColoredBox` 拦截下方所有交互（触摸事件被遮罩消费，列表不可操作）
- 转圈居中，明确「正在处理」

### 流程改动

`_renameList` / `_deleteList` 在确认弹窗关闭后：

1. `setState(() => _busy = true)`
2. 发起请求（`renameList` / `deleteList`）
3. 成功后 `refresh`（服务器为准重载，清分页状态）
4. 失败则 SnackBar 提示（文案不变）
5. `finally` 中 `setState(() => _busy = false)`（成功/失败都复位）

弹窗本身在蒙版之前关闭（用户已确认），蒙版只覆盖请求阶段。

### 测试

- fake dataSource 的 `renameList` / `deleteList` 支持可控延迟
  （`Completer`），用于验证请求期间的状态
- 用例：
  - 编辑请求进行中：蒙版可见（`CircularProgressIndicator` + 遮罩），
    列表不可交互
  - 删除请求进行中：蒙版可见
  - 请求完成后：蒙版消失
  - 失败路径：蒙版消失 + 错误 SnackBar（既有断言保留）

## 不做的事（YAGNI）

- 不做通用 loading 组件（仅本页两处使用，内联 `Stack` 足够）
- 不做蒙版「取消」按钮（请求不可中断）
- 不动排序切换、翻页加载（各自已有加载指示）
