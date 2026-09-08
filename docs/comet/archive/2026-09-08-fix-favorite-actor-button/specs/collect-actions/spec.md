# 收藏操作（collect-actions）完整目标规格

## 概述

收藏操作服务层（`FavoritesService`，lib/features/profile/services/collections_service.dart）提供各内容实体的收藏/取消收藏能力：`setCollected`（按类别收藏或取消）与 `uncollectXxx`（单实体取消收藏），统一通过 `POST /api/v1/{entity}/{id}/collect_actions` 端点完成。收藏入口 UI 包括通用列表页与演员详情页 AppBar 的心形收藏按钮（共享组件 `FavoriteButton`）。

## collect_actions 请求契约

- 请求方式：`POST {entityPath}/{id}/collect_actions`，`entityPath` 按类别映射：片商 m→/makers、系列 s→/series、导演 d→/directors、番号 c→codes 路径、清单 l→/lists、演员 a→/actors。
- 请求体编码：multipart 表单（`FormData.fromMap`），表单字段 `name` 取值 `collect`（收藏）或 `uncollect`（取消收藏）。
- 不使用 JSON 请求体：服务器按 multipart 表单字段解析 `name`，空请求或 JSON 请求体会被拒绝（`ParameterInvalid: name`）。
- 该契约适用于全部类别（演员 a、片商 m、系列 s、导演 d、番号 c、清单 l）的 collect_actions 请求，由共享方法 `_postCollect` 统一实现。
- 批量取消收藏演员（`batchUncollectActors`，DELETE /api/v1/actors/batch_uncollection）不属于 collect_actions 契约，请求方式保持现状。

## 演员详情页收藏交互

- 演员详情页 AppBar 心形按钮使用共享组件 `FavoriteButton`：空心=未收藏，实心红色=已收藏，请求进行中禁用。
- 初始状态来自演员详情接口返回的 `has_collected` 字段（含 `actor` 内层与根层两处来源），进入页面即正确显示。
- 点击心形触发 `setCollected('a', id, !hasCollected)`；请求成功后将本地状态翻转并显示"已收藏"/"已取消收藏"提示（服务器为准，不做乐观更新）。
- 请求失败时状态不变，显示"操作失败，请重试"。
- 未登录（无 ApiClient 实例）或请求进行中重复点击不产生副作用。

## 其他收藏入口的一致行为

- 通用列表页（片商/系列/导演/番号/清单/影片列表）AppBar 心形按钮的收藏/取消收藏走同一 `setCollected` 路径，请求编码与演员一致。
- 收藏的片商/系列/导演/番号/清单页的左滑取消收藏（`uncollectXxx`）走同一 `_postCollect` 路径，请求编码与演员一致。

## 非目标

- 不改变 `FavoriteButton` 的视觉样式与各页面 AppBar 布局。
- 不改变收藏状态的初始加载与解析逻辑。
- 不改变批量取消收藏演员的请求方式与交互。
- 不改变 movie_actions（清单加片/移片）等非 collect_actions 端点的请求方式。

## 场景

### Scenario: 点击未收藏演员的心形后变为已收藏

Given 演员详情页当前演员未收藏（心形为空心），且设备已登录
When 点击 AppBar 心形按钮且收藏请求成功返回
Then 心形变为实心红色，页面出现"已收藏"提示，再次进入详情页仍显示已收藏

### Scenario: 点击已收藏演员的心形后取消收藏

Given 演员详情页当前演员已收藏（心形为实心红色），且设备已登录
When 点击 AppBar 心形按钮且取消收藏请求成功返回
Then 心形变回空心，页面出现"已取消收藏"提示

### Scenario: collect_actions 请求使用 multipart 表单编码

Given 用户对任一类别实体触发收藏或取消收藏
When 客户端发送 `POST {entity}/{id}/collect_actions`
Then 请求体为 multipart 表单且仅含字段 `name`，取值为 `collect` 或 `uncollect`，不发送 JSON 请求体

### Scenario: 请求失败时收藏状态不切换

Given 演员详情页当前演员未收藏且 collect_actions 请求失败
When 点击 AppBar 心形按钮
Then 心形保持空心不变，页面出现"操作失败，请重试"提示

### Scenario: 已收藏演员进入详情页显示实心

Given 当前用户已收藏某演员且演员详情接口返回 `has_collected: true`
When 进入该演员的详情页
Then AppBar 心形按钮初始即为实心红色
