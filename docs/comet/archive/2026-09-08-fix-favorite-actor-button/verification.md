---
generated_from_state_version: 13
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 3
- 完成时间: 2026-09-08T08:48:29.433Z
- 摘要: 独立复核确认通过：根因修复真实且最小——collections_service.dart:160-165 将 _postCollect 从 JSON {'name': name} 改为 FormData.fromMap({'name': name}），六类实体的 uncollectXxx（134-155）与 setCollected（198-202）全部经由该单点，影响面恰为 collect_actions；与实测契约（authenticated.md:415-461、493-503、723-733）及仓库既有 movie_actions FormData 先例（movie_detail_service.dart:116-121）一致。新增 4 项演员详情页 widget 测试与更新后的服务层 FormData 断言真实校验 multipart 字段并覆盖 A1-A10 全部场景（含失败不翻转与初始实心）；屏幕端交互逻辑（服务器为准、busy 禁用、未登录守卫）与规格相符且未被改动。本人实跑复核：flutter analyze --no-pub 无问题；flutter test --no-pub 两目标文件 19 项全通过。工作区 HEAD 即 07d8fb7，diff 与验收文档一一对应。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1: 在演员详情页，对一个未收藏的演员点击 AppBar 心形按钮，收藏请求成功后心形立即变为实心（红色），并出现"已收藏"提示。 | widget 测试『点击空心收藏按钮后请求成功并切换为实心』通过：tap tooltip '收藏'后断言 Icons.favorite 出现、favorite_border 消失、find.text('已收藏')，并断言 POST 请求 data 为 FormData 且 fields 为 {'name':'collect'}；页面逻辑 actor_detail_screen.dart:55-62 请求成功后才翻转 has_collected 并弹'已收藏' SnackBar，与'服务器为准不乐观更新'的规格一致。 |
| A2 | passed | brief.md | A2: 在演员详情页，对一个已收藏的演员点击 AppBar 心形按钮，请求成功后心形立即变回空心，并出现"已取消收藏"提示。 | widget 测试『点击实心收藏按钮后取消收藏并切换为空心』通过：断言变回 favorite_border、find.text('已取消收藏')、请求 fields 为 {'name':'uncollect'}；页面 actor_detail_screen.dart:60-62 依据翻转前状态显示'已取消收藏'。 |
| A3 | passed | brief.md | A3: 收藏/取消收藏演员的请求按实测 API 契约以 multipart 表单编码发送（`POST /api/v1/actors/{id}/collect_actions`，表单字段 `name` 取值 `collect`/`uncollect`），不再发送 JSON 请求体。 | _postCollect 统一改为 FormData.fromMap({'name': name})（collections_service.dart:160-165），FormData 即 multipart 表单编码；服务层与 widget 测试均以 isA<FormData>() + fields 断言替换原 JSON 断言；实测契约文档 authenticated.md:415-425 确认 actors collect_actions 要求 multipart form field name（live verified values collect/uncollect）；与既有 FormData 先例 movie_detail_service.dart:116-121 toggleMovieInList 同构。 |
| A4 | passed | brief.md | A4: 进入已收藏演员的详情页（详情接口返回 `has_collected: true`），心形初始即为实心状态。 | widget 测试『已收藏演员进入详情页心形初始为实心』通过：详情响应 has_collected:true 时 find.byIcon(Icons.favorite) 且无 favorite_border；解析链 normalizeActorDetailJson（api_data.dart:203-206，actor 内层优先、root 兜底）→ actor.g.dart:39 → actor_detail_screen.dart:164-168 传入 FavoriteButton。 |
| A5 | passed | brief.md | A5: 同一共享方法 `setCollected` 支持的其他类别（片商 m/系列 s/导演 d/番号 c/清单 l）的 collect_actions 请求编码方式与 A3 一致。 | 全部类别共用唯一 _postCollect 入口（collections_service.dart:134-155 各 uncollectXxx、198-202 setCollected 均经 160-165）；服务层测试 'uncollectMaker/Series/Director/Code/List 发送对应 POST' 对 m/s/d/c/l 五条路径逐一断言 FormData fields {'name':'uncollect'}；契约文档 439-449/451-461/427-437/723-733/493-503 确认五类端点 multipart name 契约相同。 |
| A6 | passed | specs/collect-actions/spec.md | 点击未收藏演员的心形后变为已收藏 Given 演员详情页当前演员未收藏（心形为空心），且设备已登录 When 点击 AppBar 心形按钮且收藏请求成功返回 Then 心形变为实心红色，页面出现"已收藏"提示，再次进入详情页仍显示已收藏 | A1 场景版：widget 测试验证点击→实心红色（favorite_button.dart:22-23 Colors.redAccent）→'已收藏'提示→请求 name=collect；'再次进入仍显示已收藏'由初始状态渲染测试（has_collected:true→实心）与正确编码的 collect 请求共同覆盖，服务端持久化无法在单测中直接验证但链路完整。 |
| A7 | passed | specs/collect-actions/spec.md | 点击已收藏演员的心形后取消收藏 Given 演员详情页当前演员已收藏（心形为实心红色），且设备已登录 When 点击 AppBar 心形按钮且取消收藏请求成功返回 Then 心形变回空心，页面出现"已取消收藏"提示 | A2 场景版：widget 测试验证实心→点击→空心→'已取消收藏'提示→请求 name=uncollect，全部通过。 |
| A8 | passed | specs/collect-actions/spec.md | collect_actions 请求使用 multipart 表单编码 Given 用户对任一类别实体触发收藏或取消收藏 When 客户端发送 `POST {entity}/{id}/collect_actions` Then 请求体为 multipart 表单且仅含字段 `name`，取值为 `collect` 或 `uncollect`，不发送 JSON 请求体 | 场景版 multipart 断言：服务层测试覆盖 a/m/s/d/c/l 全部六类端点的 FormData fields {'name': collect/uncollect}，widget 测试再从真实页面路径断言一次；全仓 grep 确认测试中无残留 collect_actions JSON 请求体断言；batchUncollectActors（DELETE batch_uncollection，collections_service.dart:168-174）按非目标保持 JSON 未触碰。 |
| A9 | passed | specs/collect-actions/spec.md | 请求失败时收藏状态不切换 Given 演员详情页当前演员未收藏且 collect_actions 请求失败 When 点击 AppBar 心形按钮 Then 心形保持空心不变，页面出现"操作失败，请重试"提示 | widget 测试『收藏请求失败时状态不切换并提示』通过：FakeAdapter.throwFirst 抛 DioException 后断言心形仍为 favorite_border、无 favorite、find.text('操作失败，请重试')；页面 catch 分支 actor_detail_screen.dart:41-53 在翻转状态前 return 并弹失败提示，成功分支 55-59 不会执行。 |
| A10 | passed | specs/collect-actions/spec.md | 已收藏演员进入详情页显示实心 Given 当前用户已收藏某演员且演员详情接口返回 `has_collected: true` When 进入该演员的详情页 Then AppBar 心形按钮初始即为实心红色 | A4 场景版：同一初始状态 widget 测试通过（详情接口返回 has_collected:true 时 AppBar 心形初始即 Icons.favorite 实心红色）。 |

## 检查

_没有记录 Runtime 检查。_

## 阻塞项

_无。_

## 风险与跳过的工作

- A6 的'再次进入详情页仍显示已收藏'依赖服务端持久化，单测只能间接验证（请求编码正确 + has_collected 初始渲染正确），真机端到端行为建议在后续人工验收中抽查一次
- Builder 登记的全量 866 项测试通过结果未由本验收者完整重跑，仅实跑了 analyze 与两份目标测试文件（19 项）；其余测试面依赖 Runtime 复用登记

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | execution-error | — | Native Verifier response was invalid: Native Verifier response kind is invalid | 2026-09-08T08:34:20.328Z |
| 1 | 1 | 2 | execution-error | — | Native Verifier response was invalid: Native Verifier response fields are invalid | 2026-09-08T08:40:32.721Z |
| 1 | 1 | 3 | pass | — | 独立复核确认通过：根因修复真实且最小——collections_service.dart:160-165 将 _postCollect 从 JSON {'name': name} 改为 FormData.fromMap({'name': name}），六类实体的 uncollectXxx（134-155）与 setCollected（198-202）全部经由该单点，影响面恰为 collect_actions；与实测契约（authenticated.md:415-461、493-503、723-733）及仓库既有 movie_actions FormData 先例（movie_detail_service.dart:116-121）一致。新增 4 项演员详情页 widget 测试与更新后的服务层 FormData 断言真实校验 multipart 字段并覆盖 A1-A10 全部场景（含失败不翻转与初始实心）；屏幕端交互逻辑（服务器为准、busy 禁用、未登录守卫）与规格相符且未被改动。本人实跑复核：flutter analyze --no-pub 无问题；flutter test --no-pub 两目标文件 19 项全通过。工作区 HEAD 即 07d8fb7，diff 与验收文档一一对应。 | 2026-09-08T08:48:29.433Z |



## 结论

独立复核确认通过：根因修复真实且最小——collections_service.dart:160-165 将 _postCollect 从 JSON {'name': name} 改为 FormData.fromMap({'name': name}），六类实体的 uncollectXxx（134-155）与 setCollected（198-202）全部经由该单点，影响面恰为 collect_actions；与实测契约（authenticated.md:415-461、493-503、723-733）及仓库既有 movie_actions FormData 先例（movie_detail_service.dart:116-121）一致。新增 4 项演员详情页 widget 测试与更新后的服务层 FormData 断言真实校验 multipart 字段并覆盖 A1-A10 全部场景（含失败不翻转与初始实心）；屏幕端交互逻辑（服务器为准、busy 禁用、未登录守卫）与规格相符且未被改动。本人实跑复核：flutter analyze --no-pub 无问题；flutter test --no-pub 两目标文件 19 项全通过。工作区 HEAD 即 07d8fb7，diff 与验收文档一一对应。
