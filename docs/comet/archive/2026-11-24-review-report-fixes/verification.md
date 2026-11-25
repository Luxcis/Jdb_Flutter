---
generated_from_state_version: 8
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-11-24T10:19:54.629Z
- 摘要: 26 项全部独立核对：逐项阅读实现与断言语义，并独立运行 33 个相关测试文件（共 267 个用例）全部通过；format 退出码、CI 两个构建 job 的格式检查、以及“仅格式→逻辑”两段提交的可复现性均独立复核（format 提交由 HEAD 内容重跑 dart format 后逐文件 hash 全等）。判定 26 项全部 pass，另记录 4 条非阻断风险。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1: 启动请求不再固定单一兜底域名：冷启动时按持久化可用线路（key_baseurl/apiDomains）、备用域名、兜底域名的顺序尝试；主域不可达而本地存在可用线路时能成功进入主页；全部候选失败时仍显示启动失败页，且重试会重新遍历候选而非重复同一 URL。 | startup_provider.dart:71-111 每次 load 注入 DomainManager.candidateBaseUrls 并 while 轮询/useNextDomain；domain_manager.dart:58-67 候选顺序 currentUrl→apiDomains→backup/permanent/unblock→fallback 且去重；startup_screen.dart:30-35,86-89 失败页重试走 retry()→load() 重新遍历。独立运行 startup_api_client_test 6 用例（持久化线路优先、608 换域、全候选失败后重试序列 persisted/second/fallback 重复一遍、解码失败不换域）通过。 |
| A2 | passed | brief.md | A2: 线路轮转按请求生效：同一进程内首次 608/连接错误触发一次轮转，之后新的失败请求仍可再次轮转；并发失败请求只触发一次 `rotate()`（域名列表为 2 时不会双跳回原失效域名）；测试覆盖连续两次轮转。 | domain_switch_interceptor.dart:11,36-46,106-109 标记存 RequestOptions.extra 且 finally 清除；:51-59 _pendingRotation 串行化 rotate；:74-87 已切换则复用目标线路不双跳；:93-96 重试 DioException 原样透传。独立运行 domain_switch_interceptor_test 9 用例（连续两次 608 两次轮转且 extra 无残留、并发 rotations==1 且 a/b 各 2 次、重试 500 保留 response）通过。 |
| A3 | passed | brief.md | A3: 服务端下发域名在应用为 baseUrl 前校验：非 `https` scheme、空 host 的条目被丢弃；全部不合规时保持当前域名不变；合规条目正常生效且不把不合规列表持久化为可用线路。 | domain_manager.dart:71-91 校验 https+非空 host 并去重；:128-153 applyStartup 先过滤、全不合规提前返回不持久化；:97-121 load 过滤；:155-166 select 拒绝。独立运行 domain_manager_test 下发校验组（http/空 host/非法串丢弃、全不合规保持并可继续轮转、load/select 过滤）通过。 |
| A4 | passed | brief.md | A4: 本地会话/用户数据损坏不影响启动：secure storage 或旧 prefs 中的 `key_auth_session`/`key_user` 为畸形 JSON 或非对象时，不抛异常、删除坏键、按未登录继续启动并进入登录引导；新增畸形数据回归测试；`_bootstrap` 区分可重试与不可重试错误。 | auth_provider.dart:43-56,104-145,149-196 secure 与 legacy prefs 解码全程 try/catch，坏值删除并按未登录继续；main.dart:51-82 _bootstrap 按网络/超时分类 retryable 并传 StartupFailureScreen；startup_failure_screen.dart:32-36 两套中文文案且原始异常不进页面。独立运行 auth_provider_corruption_test 9 用例（含删除失败不阻断）与 startup_failure_screen_test 2 用例通过。 |
| A5 | passed | brief.md | A5: 启动响应字段类型漂移不阻断启动：`recent_keywords`/`recent_magnet_keywords` 中的非字符串项被跳过，`settings`/`user` 类型异常降级为空/null，启动仍成功且其余字段可用。 | startup.dart:47-98 _stringListOrEmpty/_stringOrNull/_mapOrNull 容错，startup.g.dart 调用。独立运行 startup_test 字段漂移组（混合类型跳过、非列表降空、settings/user 不符降 null 且 returnsNormally、异常字段不影响其他字段）通过。 |
| A6 | passed | brief.md | A6: 退出登录在安全存储写失败时仍能登出：内存 token/user 先清空并通知，持久化失败被捕获记录；个人页退出有异常保护并进入未登录态/首页；会话过期分支的重定向不再被 `isLogged` 拦截。 | auth_provider.dart:242-252 logout 先清内存并 notify 再 best-effort tombstone；profile_screen.dart:126-155 退出有 try/catch、成功后才清密码与关注缓存、最后 go('/home')；app_router.dart:73-76 _allowAuthErrorLoginOnce 防过期重定向被 isLogged 弹回。独立运行 auth_provider_test 写失败仍登出、profile_screen_test 写失败仍回首页并清关注、session_refresh_service_test expired 用例通过。 |
| A7 | passed | brief.md | A7: 未登录访问 `/profile/**` 由路由重定向到登录页；会话失效被全局踢出时使用 go/replace 清理受保护页，返回键不能回到已登出的受保护页面；认证状态变化会重新求值路由。 | app_router.dart:32-41 refreshListenable=AuthProvider.authRevision；:68-99 redirect 按 matchedLocation 拦截未登录 /profile/ 子页并带 from；:52-66 goLoginForAuthError 用 go 替换栈。独立运行 app_router_auth_test 12 用例（未登录重定向、登录后重求值、登出后替换为 login、canPop==false、登录态下全局失效不被弹回）通过。 |
| A8 | passed | brief.md | A8: “我看过的”不再指向恒空占位页：使用真实 `status=watched` 数据源，有看过记录时展示影片列表；顶部 Tab 与筛选入口不再共用空 controller/空回调。 | app_router.dart:273-289 /profile/watched 指向 ProfileReviewMoviesScreen(title:'我看过的',status:'watched')、关注路由直连 FollowingScreen；profile_review_movies_screen.dart 每 Tab 独立 ReviewMoviesTabController 且排序回调真实下发；review_movies_service.dart 请求 status/type/sort_by/order_by/page。独立运行 app_router_requirements_test 我看过的渲染真实页、profile_review_movies_page_test 按 Tab 请求/排序/第二页用例通过。 |
| A9 | passed | brief.md | A9: 预告片进度条 seek 以进度条自身宽度为分母：点击/拖动到进度条某位置 seek 到对应比例时长，点击最右端接近视频结尾；尾部填充跟手；新增断言 seek 目标位置的测试。 | movie_preview_controls_overlay.dart:480-512 _progressBar 内 LayoutBuilder 以 constraints.maxWidth 为分母，:514-556 拖动 _scrubPreview 填充跟手，:558-575 clamp 后 seek。独立运行 movie_preview_controls_overlay_test 50% 点击=60s、最右端>95%、拖动 0.75 填充且 seek 90s 三用例通过。 |
| A10 | passed | brief.md | A10: 播放操作层在缓冲/暂停恢复后重新开始自动隐藏计时；初始即处于缓冲的场景在恢复播放后也能自动隐藏；手动唤起后同样按规则隐藏。 | movie_preview_controls_overlay.dart:144-164 _onStateChanged 记录 wasAutoHideable，false→true 时 _resetHideTimer。独立运行初始缓冲→播放、暂停→播放、手动唤起后隐藏 4 用例通过。 |
| A11 | passed | brief.md | A11: 剧照缩略图按槽位高度×DPR 限制解码尺寸（memCacheHeight 等），宽高比测量复用同一有界 provider 或使用已记忆比例；全屏图库仍按原图展示。 | movie_still_thumbnail.dart:80-103 按 slotHeight×DPR 传 memCacheHeight，已记忆比例时不再监听尺寸；cached_image.dart:55-68 ResizeImage 包装同一有界 provider 供 ImageSizeListener；basic_info_sections.dart 槽高 164；image_gallery_viewer.dart:93-97 全屏不限高。独立运行 movie_still_thumbnail_test（DPR=2→328、无槽高→null、记忆比例不重复监听）与 cached_image_test（memCache 492、ResizeImage 复用）通过。 |
| A12 | passed | brief.md | A12: 榜单响应缺少 `total_pages` 时按“本页满页则 totalPages=page+1，否则 page”推断，有码/无码/欧美/FC2 榜单可加载第 2 页；服务端 `current_page` 前移时当前页判断仍正确。 | ranking_service.dart:56-70 传 page、:90-116 缺 total_pages 时 currentPage+(满页?1:0) 且保留服务端 current_page；rank_tabs.dart:128-141 用 PaginationController 按 totalPages 续页。独立运行 ranking_service_test 推断组（满页→2 可续、短页→1、current_page 前移→3、服务端值优先、播放榜不推断）通过。 |
| A13 | passed | brief.md | A13: Top250 使用服务端返回的 `ranking` 渲染名次（`ignore_watched` 过滤后名次可跳号且不再被改写为连续编号）；末页判断按 start_rank 上限或 total 收敛，短页不提前截断。 | movie.dart:26-31/movie.g.dart:18 解析 ranking，api_data.dart:88 归一化；top250_tab.dart:35-57 按 start_rank>250 或空页收敛、:150 rank=movie.ranking ?? startRank+index。独立运行 rankings_screen_test Top250 组（跳号 1/4/7、过滤短页继续请求 51、空页停止、201 起停止、51→101 且第 101 名）通过。 |
| A14 | passed | brief.md | A14: 加载更多失败后，`PaginatedListView`、`MovieGridView`、`ActorGridView` 的滚动监听在 `error != null` 或 `hasMore == false` 时不再自动重发请求；仅用户点击“重试”按钮才重新请求。 | paginated_list_view.dart:35-46、movie_grid_view.dart:74-82、actor_grid_view.dart:89-99 均在 error!=null 或 !hasMore 时跳过 fetchMore，仅页尾重试按钮触发。独立运行三文件“加载更多失败后继续滚动不重发、点重试才重发”用例（请求序列 [1,2]→点击后再次 2）通过。 |
| A15 | passed | brief.md | A15: core 提供统一的 `userFacingErrorMessage(Object error)`：ApiException 显示服务端中文 message，连接/超时显示“网络连接失败，请检查网络”，其余显示“加载失败，请重试”；所有 ErrorRetryWidget 调用点与首页分区错误不再展示 DioException 原始英文串。 | core/utils/user_facing_error.dart 统一映射（ApiException message→中文，连接/超时→网络连接失败，其余→加载失败）；全仓 ErrorRetryWidget 调用点均传映射结果或中文常量；home_provider.dart:26-27 分区错误用映射。独立运行 user_facing_error_test 7 用例通过；grep 仅 movie_preview_playback.dart:175 保留原始串（非 ErrorRetryWidget 调用点，Builder 已披露）。 |
| A16 | passed | brief.md | A16: 演员详情加载失败时展示中文错误文案与重试按钮，点击后重新加载；重试开始时错误态被重置，成功后正常展示内容。 | actor_detail_screen.dart:74-84 重试先 dispose 旧 controller 并清 _error/_isLoading，:157-164 错误态 ErrorRetryWidget(userFacingErrorMessage)。独立运行 actor_detail_screen_test 网络失败显示中文且无 DioException、点击重试后恢复内容、服务端中文 message 直出用例通过。 |
| A17 | passed | brief.md | A17: 登录/注册失败时展示服务端中文 message 而非 DioException 技术串（不再出现 “DioException [bad response]” 前缀）；响应缺少 token/user 时给出明确中文提示且不抛 TypeError；新增断言错误文案的测试。 | login_screen.dart:72-151 显式校验 token/user 缺失并提示“登录响应缺少登录凭证”，错误经 userFacingApiException/userFacingErrorMessage；register_screen.dart:76-95 同样解包 DioException.error。独立运行 login_register_error_test 5 用例（登录/注册服务端中文、缺 token/user/data 不抛 TypeError 且无技术串）通过。 |
| A18 | passed | brief.md | A18: 注册页与登录页表单可滚动：键盘弹起或系统大字号时内容可滚动到提交按钮，不再出现 RenderFlex overflow，错误提示可见。 | login_screen.dart:176-272、register_screen.dart:107-203 为 LayoutBuilder→SingleChildScrollView→ConstrainedBox→IntrinsicHeight，提交按钮与错误提示在滚动内容内。独立运行 auth_form_scroll_test（320x480、textScaler=2、inset 200，断言无 overflow、按钮/错误可达）通过。 |
| A19 | passed | brief.md | A19: 演员卡选中态使用 `colorScheme.onPrimary` 等语义色，暗色主题下勾选图形对比度达到非文本 3:1；Semantics 暴露选中状态。 | actor_card.dart:37-43 Semantics(selected:selected)，:71-88 徽章底色 primary、图标 onPrimary，无字面量颜色。独立运行 actor_card_test 明暗主题对比度≥3、selected 语义 True/False 用例通过。 |
| A20 | passed | brief.md | A20: 名次徽章前景/底色对比度达到 4.5:1（或采用等效深色前景方案），读屏朗读包含“第 N 名”。 | rating_badge.dart:13-30 前三名成对深浅配色、:46-59 Semantics(label:'第 N 名', excludeSemantics:true)。独立运行 rating_badge_test 实际渲染色对比度≥4.5、前景非白、语义只读一次（含第 12 名）用例通过。 |
| A21 | passed | brief.md | A21: 首页推荐轮播在系统开启“减少动态效果”时不自动切换；提供用户可操作的暂停/播放控制；现有触摸暂停与滚动行为不回退。 | recommend_carousel.dart:62-67 MediaQuery.disableAnimationsOf，:42-47/109-121 减少动效时 autoPlay=false，:159-182 暂停/播放角标（减少动效时禁用并 tooltip 说明）。独立运行 recommend_carousel_test 减少动效不切换且按钮禁用、暂停/恢复、暂停中手动滑动保持、单图无按钮用例通过。 |
| A22 | passed | brief.md | A22: 通过认证 Token 弹窗换号后，关注标签缓存被清空或按新账号同步；冷启动不再把上一账号的标签作为 batch_push 推给新账号。 | profile_settings_screen.dart:100-113 Token 弹窗在 auth.login 成功后 following.clear()；following_tags_provider.dart:80-84 清内存并持久化。独立运行 token_authentication_following_tags_test：换号后 tags/store 为空，模拟冷启动 syncFromRemote 的 batch_push 为空列表。 |
| A23 | passed | brief.md | A23: feature 之间不再存在横向 import（categories/profile 不再 import following）：关注按钮位于 core；仅做透传的 ProfileFollowingScreen 删除且路由直连 FollowingScreen；lib/features/settings/ 死代码删除；STRUCTURE.md/RULES.md 相关描述与实际一致。 | lib/core/widgets/following_tags_button.dart 存在且 categories_screen.dart:189 引用；自写扫描 lib/features 跨 feature import 命中 0；lib/features/settings/ 已不存在、grep features/settings 无命中；ProfileFollowingScreen 无引用且 app_router.dart:283-289 直挂 FollowingScreen；STRUCTURE.md/RULES.md diff 修正 settings 行、router 顶层位置与关注按钮归属。 |
| A24 | passed | brief.md | A24: 片商/导演/系列复用同一个 core 泛型“Tab + 分页列表”屏；TabController 长度取自 children 长度；三个页面的加载/空态/错误/分页行为与改动前一致。 | core/widgets/entity_tab_list_screen.dart:47-55 TabController 取 tabs.length，:64-84 TabBar/TabBarView 同源，:104-131 每 Tab 独立 PaginationController + AutomaticKeepAlive。makers/directors/series 仅提供数据源与 tile。独立运行 entity_tab_list_screen_test 6 用例（Tab 长度=children、加载、Tab 级空态、错误重试、分页、保活不重复请求）通过。 |
| A25 | passed | brief.md | A25: 测试补齐且有效：注册页覆盖两次密码不一致、密码过短、接口报错、成功跳转（含 from）四个分支；注册 API 测试直接调用 `AuthSessionService.register` 并断言提交字段；演员详情覆盖筛选 tags/sort/order 参数与信息面板占位符；CachedImage 测试断言 imageUrl、width、height 与域名前缀。 | 注册四分支：auth_form_scroll_test 两次密码不一致；register_screen_test 密码过短（断言 0 请求）与成功跳转保留 from；login_register_error_test 接口报错中文。auth_session_service_test 直接调 AuthSessionService.register 并断言 11 个提交字段；actor_movie_controller_test 断言 filter_by_tags/sort_by/order_by；actor_filter_and_info_sheet_test 断言 -- 与 N 岁；cached_image_test 断言 CDN 前缀、width/height、memCache 透传。以上均独立运行通过。 |
| A26 | passed | brief.md | A26: 全仓 `dart format --output=none --set-exit-if-changed lib test` 退出码 0；CI 构建流程包含该格式检查步骤；逻辑改动与纯格式改动在提交中可区分。 | 独立执行 dart format --output=none --set-exit-if-changed lib test → Formatted 416 files (0 changed), exit 0；compile_apk.yml:58-60 与 :147-149 两个构建 job 均含该步骤；可分离性：存在 063b2ef（父 0704295，83 文件）与 c125cfe（父 063b2ef，86 文件），我在 /tmp 用 git archive 取 0704295 的 lib/test 运行 dart format 后逐文件 hash 与 063b2ef 全量比对 0 差异，并确认 c125cfe 树与当前工作区（含 14 个未跟踪新文件）逐文件 hash 全一致，两段提交序列可复现。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| 全仓格式检查 | format --output=none --set-exit-if-changed lib test | . | passed | 0 | 802 ms |
| 静态分析 | analyze --no-pub | . | passed | 0 | 4710 ms |
| 全量测试 | test --no-pub | . | passed | 0 | 31991 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- dart format --output=none --set-exit-if-changed lib test: passed — Formatted 416 files (0 changed), exit 0
- flutter analyze --no-pub: passed — No issues found! (3.6s)
- flutter test --no-pub: passed — 00:29 +1123: All tests passed!
- grep features/settings|ProfileFollowingScreen|cross-feature import: passed — 三条 grep 均无命中
- 已知限制: 服务端契约（榜单缺 total_pages、Top250 ranking、review_movies）按文档语义实现并由单测覆盖，未联机验证。
- 已知限制: backupUrls/permanentAppDomain/unblockAppDomain 仅在同一进程内参与启动候选，未跨冷启动持久化（需新增存储键，超出本批文件范围）；冷启动候选仍包含 currentUrl/apiDomains/兜底。
- 已知限制: movie_preview_playback.dart:175 的媒体错误描述仍为原始错误串（不是 ErrorRetryWidget 调用点，不在 A15 确认范围）。
- 已知限制: README.md 的版本号/测试数/目录描述漂移属 MOD-6（P2 非目标），未处理。
- 已知限制: A26 的纯格式/逻辑两段提交将在 SDK 归档完成后执行；归档前提交会使候选指纹漂移，故当前仅在临时 worktree 预演。

## 阻塞项

_无。_

## 风险与跳过的工作

- A1 字面顺序中的备用域名（backupUrls/permanentAppDomain/unblockAppDomain）不跨进程持久化：冷启动候选为 currentUrl→apiDomains→兜底，备用域名仅在同进程 startup 成功后才进入候选；Builder 已披露，核心验收行为均有测试覆盖。
- A7 的 /profile/settings 与 /profile 被有意排除在重定向之外（/profile 未登录展示登录引导，settings 承载本地线路/主题），与“/profile/** 全部重定向”的字面表述存在差异。
- A26 的两段提交目前是可达的预演 git 对象（063b2ef/c125cfe），未写入 dev 分支；受“SDK 候选归档前不得提交”约束，归档时需按该序列落地。
- 服务端契约（榜单缺 total_pages、Top250 ranking、review_movies status=watched）仅按文档语义与单测验证，未联机实测。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 26 项全部独立核对：逐项阅读实现与断言语义，并独立运行 33 个相关测试文件（共 267 个用例）全部通过；format 退出码、CI 两个构建 job 的格式检查、以及“仅格式→逻辑”两段提交的可复现性均独立复核（format 提交由 HEAD 内容重跑 dart format 后逐文件 hash 全等）。判定 26 项全部 pass，另记录 4 条非阻断风险。 | 2026-11-24T10:19:54.629Z |



## 结论

26 项全部独立核对：逐项阅读实现与断言语义，并独立运行 33 个相关测试文件（共 267 个用例）全部通过；format 退出码、CI 两个构建 job 的格式检查、以及“仅格式→逻辑”两段提交的可复现性均独立复核（format 提交由 HEAD 内容重跑 dart format 后逐文件 hash 全等）。判定 26 项全部 pass，另记录 4 条非阻断风险。
