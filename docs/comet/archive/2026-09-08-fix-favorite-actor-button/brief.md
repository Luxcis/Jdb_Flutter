# 目标

修复演员详情页心形收藏按钮"点击后状态不切换"的问题，使其收藏/取消收藏行为与片商、系列、导演、番号、清单等其他收藏功能保持一致（点击后请求成功即切换心形状态并给出提示）。

# 范围

- `lib/features/profile/services/collections_service.dart`：`_postCollect` 的请求体编码（collect_actions 系列端点）。
- `lib/features/actors/screens/actor_detail_screen.dart`：演员详情页收藏交互（仅因共享服务层修复而恢复正常，交互逻辑不变）。
- 相关测试：`test/features/profile/collections_service_test.dart`（请求体断言）、新增演员详情页收藏交互测试。

# 非目标

- 不修改 `FavoriteButton` 组件的视觉样式（各页已共用，渲染一致）。
- 不修改演员详情页收藏状态的初始加载（详情接口 `has_collected` 已正确解析，初始显示正常）。
- 不修改各收藏页的取消收藏交互方式（左滑/编辑批量均保持现状）。
- 不修改 `batchUncollectActors`（DELETE batch_uncollection）的请求方式。
- 不修改 `toggleMovieInList` 等 movie_actions / 清单接口。

# 验收示例

- A1: 在演员详情页，对一个未收藏的演员点击 AppBar 心形按钮，收藏请求成功后心形立即变为实心（红色），并出现"已收藏"提示。
- A2: 在演员详情页，对一个已收藏的演员点击 AppBar 心形按钮，请求成功后心形立即变回空心，并出现"已取消收藏"提示。
- A3: 收藏/取消收藏演员的请求按实测 API 契约以 multipart 表单编码发送（`POST /api/v1/actors/{id}/collect_actions`，表单字段 `name` 取值 `collect`/`uncollect`），不再发送 JSON 请求体。
- A4: 进入已收藏演员的详情页（详情接口返回 `has_collected: true`），心形初始即为实心状态。
- A5: 同一共享方法 `setCollected` 支持的其他类别（片商 m/系列 s/导演 d/番号 c/清单 l）的 collect_actions 请求编码方式与 A3 一致。

# 约束与不变量

- 实测 API 契约（docs/main/api/assist/authenticated.md:415-425）：`POST /api/v1/actors/{id}/collect_actions` 要求 multipart form field `name`，实测值为 `collect`/`uncollect`，空请求报 `ParameterInvalid: name`。directors/makers/series/lists/codes 的同名端点契约相同。
- 仓库内同类端点的既有可用模式：`movie_detail_service.toggleMovieInList` 对 `lists/{id}/movie_actions` 使用 `FormData.fromMap`（lib/features/movie_detail/services/movie_detail_service.dart:117-121）。
- 收藏状态切换时机与其他收藏页一致：请求成功后再更新本地状态（服务器为准），失败显示"操作失败，请重试"，请求期间按钮禁用（busy）。
- OpenAPI 规范中 `CollectActorRequest.name` 描述为"演员名称"，与实测笔记冲突；以实测笔记（live verified values: collect/uncollect）为准。

# 决策

- D1（用户确认）: "收藏演员功能的按钮"指演员详情页右上角心形收藏按钮；现象为点击后状态不切换。
- D2: 根因为 `_postCollect` 以 JSON 发送 `{'name': ...}`，而服务器要求 multipart 表单字段 `name`，演员端点拒绝该请求导致 catch 分支提示失败、状态不翻转。
- D3: 修复方式为共享方法 `_postCollect` 统一改用 `FormData.fromMap({'name': name})`，所有实体的 collect_actions 一并符合实测契约；不做按类别的请求编码分叉。

# 待解决问题

（无）

# 验证预期

- `flutter test` 全量通过；`collections_service_test` 更新为断言 FormData 请求体（含 name 字段取值）。
- 新增演员详情页收藏交互 widget 测试：点击心形触发 collect_actions 请求并在成功后切换状态。
- `flutter analyze` 无新增告警。
