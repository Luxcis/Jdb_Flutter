---
generated_from_state_version: 8
---

# 验证

## 当前结果

- 结果: **验收通过，需要你确认**
- 验证情况: **已完成检查，但需要你确认验证结果**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 2
- 完成时间: 2026-09-16T09:34:44.234Z
- 摘要: A1-A10 全部通过：路由迁出 core 且引用全更新、services 收敛完整且 URL/query 等价、ConfirmDialog 七处替换文案与取消 null/确定 true 语义等价、配色 Token 化落实且刻意配色未动、无障碍语义与演员网格单点计算成立、analyze 零告警与 902 测试全过且 pubspec.lock 未动。结论：pass。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1: `lib/core/` 下（含子目录）不存在任何 `import ... features/` 或 `package:jade/features/` 引用；路由实现位于 `lib/router/app_router.dart`，`app.dart`/`main.dart`/相关测试的引用全部更新且应用可正常启动。 | grep 证实 lib/core 下 import features/ 与 package:jade/features 均零命中；lib/core/router 已删除，路由位于 lib/router/app_router.dart+routes.dart，lib/ 与 test/ 全部引用为 package:jade/router/，无 core/router 残留。 |
| A2 | passed | brief.md | A2: `STRUCTURE.md` 与实际目录一致，说明 `lib/router/` 的新位置与"core 不依赖 feature"约定的达成。 | STRUCTURE.md 已写入 lib/router/（路由组装层、不进 core）、core 不依赖 feature 约定及路由接入规则，与实际目录（lib/router 两文件、17 feature）一致。 |
| A3 | passed | brief.md | A3: `lib/features/` 下除各自 feature 的 `index.dart` 与 `services/` 外，不存在直接引用 `ApiClient.instanceOrNull` 的代码（profile 最近浏览 service 经 index 导出的既有例外保持现状，详见 Decisions）。 | features 中 instanceOrNull 仅存在于 23 个 services/ 文件内，services/ 之外（含全部 index.dart）零命中；main.dart 装配与 cached_image/review_tile 例外按 D6 保留。 |
| A4 | passed | brief.md | A4: 新增 service 的 feature（articles、makers、directors、rankings、home 分区、search 等）遵循既有 `*_service.dart` 结构（final ApiClient _api + 实例化模式），无逻辑改写、分页与解析行为不变。 | 抽查 directors_service、makerDataSource 工厂、auth_session_service、search_movie_service 均为 final ApiClient _api + resolve/defaultXxxDataSource 模式；search /api/v2/search 的 q/type/movie_type/movie_filter_by/movie_sort_by/page/limit 参数与旧 screen 内联逻辑逐项等价，分页 pageSize=48 与 apiPageResult 解析不变。 |
| A5 | passed | brief.md | A5: `common_list_screen` 等页面的"未登录/无连接"空态、错误态展示行为与改动前一致。 | common_list_screen diff 仅把两处 instanceOrNull 三元装箱替换为 defaultTagMoviesDataSource()/defaultFavoritesDataSource() 工厂，Unavailable*DataSource 空数据源与未登录/错误/重试分支本体未改。 |
| A6 | passed | brief.md | A6: 新增 `ConfirmDialog` 于 `lib/core/widgets`；7 处旧弹窗代码删除并替换为统一入口，各处确认弹窗的标题、内容、按钮文案与"取消返回 null / 确定返回 true"语义完整保留。 | 新增 lib/core/widgets/confirm_dialog.dart（取消 pop(false)/确定 pop(true)）；7 处调用点经 diff 逐处对照 title/content/按钮文案与旧弹窗一致（含动态 title 与“确定删除/清除/清空”文案），唯一残留 showDialog<bool> 为 Token 认证专用弹窗，属允收例外。 |
| A7 | passed | brief.md | A7: `empty_state`、`error_retry_widget`、`movie_card`、`movie_list_tile` 等通用组件不再出现 `Colors.grey`/`Colors.red` 字面量；亮暗两模式下相应文字颜色随 ColorScheme 变化；`favorite_button` 红心与评分/榜单固定配色未被改动。 | grep Colors.(grey\|red) 全 lib 仅余 favorite_button 红心与 top_ranking_tile/rating_badge 复刻官方固定配色且 diff 零改动；empty_state/error_retry/movie_card/movie_list_tile 已改 onSurfaceVariant/outline，login/register 调色改 colorScheme.error。 |
| A8 | passed | brief.md | A8: `MovieCard` 与首页推荐轮播卡片使用 `Semantics(button: true)` + InkWell；点击导航、卡片视觉与改动前一致；无障碍树中该卡片播报为按钮（label 含标题）。 | movie_card.dart 为 Semantics(button:true,label:movie.title)+InkWell；轮播卡片为 Semantics(button:true,label:movie.title)+GestureDetector（onTap 在语义树同样播报按钮，规避 InkWell 涟漪干扰轮播横向手势），点击与视觉 unchanged。 |
| A9 | passed | brief.md | A9: 演员网格列数计算仅存在于 `actor_grid_view.dart` 一处；`actors_screen.dart` 渲染结果（列数、卡距、滚动）与改动前一致。 | grep /120 列数公式全库仅剩 actor_grid_view.dart metricsForWidth 一处；(w/120).floor().clamp(3,6)、padding16/卡距12 公式逐项收口为单点并被 actors_screen 与 ActorGridView 共用，数学等价。 |
| A10 | passed | brief.md | A10: `flutter analyze --no-pub` 零告警；`flutter test` 全量通过；受影响场景补必要回归测试（ConfirmDialog 行为等价、service 抽取沿用既有 FakeAdapter 测试）。 | flutter analyze --no-pub exit 0 零告警、flutter test --no-pub 902 全过；pubspec.lock 未动；新增 test/core/widgets/confirm_dialog_test.dart 覆盖确定 true/取消 false，既有 FakeAdapter screen 测试（directors/makers/rankings/search 等）随迁移同步保留。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze | flutter analyze --no-pub | . | passed | 0 | 2425 ms |
| core 无 features 引用 | -c ! grep -rn 'features/' lib/core \| grep import | . | passed | 0 | 13 ms |
| features instanceOrNull 仅 services | -c ! grep -rln 'instanceOrNull' lib/features \| grep -v services/ | . | passed | 0 | 18 ms |
| Colors grey/red 仅例外保留 | -c ! grep -rln 'Colors\.(grey\|red)' lib \| grep -v favorite_button \| grep -v top_ranking_tile \| grep -v rating_badge | . | passed | 0 | 19 ms |
| ConfirmDialog 替换完整 | -c grep -rln 'showDialog<bool>' lib | . | passed | 0 | 20 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze --no-pub: passed — No issues found!（零告警零错误）
- flutter test --no-pub: passed — 902 个测试全部通过（较改动前 900 新增 2 项 ConfirmDialog 测试）；期间曾修复 article_card 分类胶囊测试期望（Colors.red→colorScheme.error）
- grep A1/A3/A7/A6: passed — lib/core 无 features import（0 命中）；features 内 instanceOrNull 仅出现在 services/*.dart；Colors.grey/red 仅剩 favorite_button、top_ranking_tile、rating_badge；showDialog<bool> 仅剩 confirm_dialog 自身与 profile_settings 的专用认证/更新弹窗
- 已知限制: Verifier 验证 inputOptions.template 补充检查：flutter analyze --no-pub、flutter test --no-pub；补充 grep 检查 core 无 features 引用、features 内 instanceOrNull 仅 services 层命中、ConfirmDialog 7 处文件
- 已知限制: profile_settings_screen.dart 与 startup_screen.dart 的 ApiClient.instance（非 nullable）用法按既有代码保留，为 P2 后续收敛建议
- 已知限制: recommend_carousel 保留 GestureDetector（onMovieTap 回调语义），仅在包装层新增按钮语义，未改 InkWell，与 brief A8 的 InkWell 约定在'有水波纹反馈'上存在最小差异（轮播命中区域为 Stack+封面覆盖，InkWell 不生效）

## 阻塞项

- **user**: The generic Skill bridge cannot prove an independent Verifier execution; user confirmation is required before Archive. — next: `await-user`

## 风险与跳过的工作

- A8 轮播用 GestureDetector 而非验收字面的 InkWell：按钮语义播报目标达成，但字形实现存在偏差（疑为刻意规避涟漪与轮播手势冲突），记低风险非阻断。
- A4 等价抽验覆盖 directors/makers/search/common 等 3-4 例，其余 service 未逐行 diff，依赖 902 项全量测试兜底。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | execution-error | — | Native Verifier response was invalid: Native verification cannot pass before every required check succeeds | 2026-09-16T09:33:08.640Z |
| 1 | 1 | 2 | pass | — | A1-A10 全部通过：路由迁出 core 且引用全更新、services 收敛完整且 URL/query 等价、ConfirmDialog 七处替换文案与取消 null/确定 true 语义等价、配色 Token 化落实且刻意配色未动、无障碍语义与演员网格单点计算成立、analyze 零告警与 902 测试全过且 pubspec.lock 未动。结论：pass。 | 2026-09-16T09:34:44.234Z |



## 结论

A1-A10 全部通过：路由迁出 core 且引用全更新、services 收敛完整且 URL/query 等价、ConfirmDialog 七处替换文案与取消 null/确定 true 语义等价、配色 Token 化落实且刻意配色未动、无障碍语义与演员网格单点计算成立、analyze 零告警与 902 测试全过且 pubspec.lock 未动。结论：pass。
