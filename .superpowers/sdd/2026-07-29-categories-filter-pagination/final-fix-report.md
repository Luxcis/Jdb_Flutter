# 分类页动态筛选与分页：最终审查修复报告

日期：2026-07-29

分支：`codex/categories-dynamic-filters`

审查依据：

- `.superpowers/sdd/2026-07-29-categories-filter-pagination/final-review.md`
- `docs/superpowers/specs/2026-07-29-categories-filter-pagination-design.md`

## 修复结果

### Important 1：extra 稳定序列化

- 新增 `CategoryFilterGroupOrder`，将接口分组顺序和每组 tag ID 顺序作为同一个有序输入传给序列化层，避免平行参数错位。
- `CategoryFilter.toFilterBy()` 依次遍历接口分组和组内 tag，只输出当前已选值；同一筛选集合不再受点击顺序影响。
- `CategoryDataSource`、`CategoryService` 和 `CategoryTabController` 统一传递完整顺序。
- 保留用户裁定的 `const CategoryFilter()`，未恢复公开的 `extraByCategory` 构造参数。
- 模型、控制器和 Widget 均覆盖“先点 51、再点 23，仍输出 23,51”。

### Important 2：真实多页和滚动状态验收

- 页面级 Widget Fake 为 Tab 0 提供真实两页数据（24 + 12），滚动进入 400px 预取区后验证请求历史为 page 1、page 2，控制器持有 36 条影片且滚动 offset 非零。
- 切换 Tab 1 后验证其只有独立 page 1、24 条影片且 offset 为 0。
- 切回 Tab 0 后验证影片数量、分页请求历史和滚动 offset 均保持。
- 单独覆盖 type 2、3、4 的首次请求，分别为 `2:t:::::`、`3:t:::::`、`4:t:::::` 且 page 为 1。
- 临时将所有 Tab 错误绑定到 Tab 0 控制器时，新多页测试按预期失败；恢复正确绑定后通过。临时变异未保留在最终差异中。

### Minor 1：dispose 后丢弃标签结果

- 标签成功 Future 在 `await` 后先检查 `_disposed`，销毁后不写 `_groups` 或 `_tagsLoaded`。
- 标签失败路径同样先检查 `_disposed`，销毁后不写 `_tagsError`。
- `finally` 在销毁后只完成等待方，不再写加载状态或通知监听器。
- 成功和失败两个回归均验证等待正常完成且公开状态保持不变。

## TDD 证据

- 模型 RED：新有序分组记录无法传入旧 `List<String>` 接口，编译失败。
- 模型 GREEN：`flutter test test/features/categories/category_filter_test.dart`，8 tests passed。
- 控制器/Widget RED：旧数据源接口缺少 `groupOrder`，编译失败。
- 控制器/Widget GREEN：两个测试文件合计 24 tests passed。
- dispose RED：成功结果实际写入 3 个 groups，失败结果实际写入 `StateError`。
- dispose GREEN：控制器 14 tests passed。
- 多页验收变异 RED：错误控制器绑定导致 Tab 1 独立状态断言失败。
- 多页验收恢复 GREEN：多页滚动测试与 type 2/3/4 映射测试通过。

## 最终验证

- `dart format`：7 个修改文件已格式化，2 个文件产生格式调整。
- `flutter test test/features/categories test/core/widgets/pagination_controller_test.dart test/core/widgets/movie_grid_view_test.dart test/api_integration_test.dart`
  - 73 tests passed，0 failed。
- `flutter test`
  - 240 tests passed，0 failed。
- `flutter analyze`
  - No issues found。
- `git diff --check`
  - 通过，无空白错误。

## 范围

仅修改分类筛选序列化接口、分类 Tab 控制器生命周期处理及相关测试；未修改既有
`.superpowers` 报告，只新增本文件。
