# 目标

按 `docs/reports/review-report.md`（多维度审查报告，72 条发现）修复用户选定的 P0+P1 范围（37 条编号，约 30 组根因）：消除启动与线路自愈的单点失效、消除坏数据导致的永久启动失败、修正明确的用户可见功能错误（“我看过的”恒空、预告片 seek 无法定位、登录失败展示英文技术串），并完成安全纵深、会话一致性、播放器、列表、错误体验、无障碍、架构收敛、测试补齐与格式基线修复。完成后 `flutter analyze --no-pub` 零问题、`flutter test --no-pub` 全部通过、`dart format` 全仓零需改。

# 范围

- 需求来源：`docs/reports/review-report.md` 第三章对应条目与第五章修复顺序；逐条映射见「来源覆盖」表。
- 覆盖的发现编号（37 条）：BASE-1、SEC-1/2/3、STATE-1/2/3/4、DATA-1/2、ERR-1/2/3/4/5、USER-1/2/3/4、PLAY-1/2/3、PERF-2、LIST-3/4/5、UIUX-2/3/4/5、ARCH-1/3、MOD-1/3、TEST-1/2/3。其中 USER-3 与 STATE-2 同根因，SEC-2 与 ERR-3、DATA-2/ERR-2/USER-3 与 STATE-2、PERF-2 与 PLAY-3、ARCH-3 与 MOD-3 合并为同一修复项。
- 不在本 change 的 35 条（含 29 条待确认）不处理、不复核，保持现状。
- 实施方式：Build 阶段使用动态 workflow 按文件所有权分区并行修复，最终形成单一候选实现；由独立只读 Verifier 按全部验收项验收。

## 目录结构

### 新建

- lib/core/utils/user_facing_error.dart — 统一错误文案映射：优先 `ApiException.message`，连接/超时→“网络连接失败，请检查网络”，其余→“加载失败，请重试”；供 ErrorRetryWidget 调用点与登录/注册共用。
- lib/core/widgets/following_tags_button.dart — 从 following feature 上提的关注标签按钮，解除 categories/profile 对 following 的横向依赖。
- lib/core/widgets/entity_tab_list_screen.dart — 片商/导演/系列共用的泛型「Tab + 分页列表」屏，Tab 长度取 children 长度。
- lib/core/widgets/domain_candidate_provider 相关的启动域名解析（如 lib/core/network/startup_domain_resolver.dart）— 汇总 DomainManager 持久化线路、备用域名与兜底域名，供启动请求依次尝试。
- test/core/network/startup_api_client_test.dart、test/core/providers/auth_provider_corruption_test.dart、test/features/auth/login_register_error_test.dart、test/core/widgets/entity_tab_list_screen_test.dart 等 — 覆盖本轮行为修复与新增容错路径的回归测试。
- test/features/actors/actor_movie_controller_test.dart、test/features/actors/actor_filter_and_info_sheet_test.dart — 演员筛选参数与信息面板测试。

### 修改

- lib/core/network/ — startup_api_client.dart 接入候选域名列表并逐个尝试；domain_manager.dart 对下发域名做 scheme/host 校验后再应用；interceptors/domain_switch_interceptor.dart 把重试标记移入每请求作用域、`rotate()` 加互斥；api_client.dart 补 sendTimeout。
- lib/core/providers/auth_provider.dart — 会话/用户解码全部包 try/catch，坏值删除并按未登录继续启动；logout 先清内存并通知、再 best-effort 写 tombstone。
- lib/main.dart、lib/router/app_router.dart — 启动失败重试重新遍历候选域名并区分可重试/不可重试错误；GoRouter 接入 `refreshListenable`，未登录访问 `/profile/**` 由 redirect 拦截，全局登出用 go/replace；“我看过的”路由改指向真实数据页。
- lib/core/models/startup.dart、startup.g.dart — 热词非字符串项跳过、settings/user 类型漂移降级为空，不再阻断启动。
- lib/core/widgets/ — movie_grid_view.dart、paginated_list_view.dart、actor_grid_view.dart 加 error/hasMore 守卫与 `AlwaysScrollableScrollPhysics`；movie_still_thumbnail.dart 按槽位限高解码并复用有界 provider；actor_card.dart 使用 ColorScheme 角色并补 `selected` 语义；rating_badge.dart 调整前景/底色并补“第 N 名”语义；所有 `error.toString()` 调用点改用统一错误文案。
- lib/features/rankings/ — ranking_service.dart 缺 `total_pages` 时按满页推断；top250_tab.dart 解析并使用服务端 `ranking`，末页判断收敛。
- lib/features/movie_detail/ — movie_preview_controls_overlay.dart 以进度条自身宽度换算 seek，并在 `_canAutoHide` 恢复时重启隐藏计时；basic_info_sections.dart 为剧照槽位传 memCacheHeight。
- lib/features/actors/ — actor_detail_screen.dart 错误态改 ErrorRetryWidget 并可重试；actor_movie_controller/筛选面板/信息面板补可测试注入点与测试。
- lib/features/auth/screens/ — login_screen.dart、register_screen.dart 解包 `DioException.error` 的 ApiException 显示中文 message、校验 token/user 缺失、表单改可滚动并处理键盘/大字号。
- lib/features/home/widgets/recommend_carousel.dart — 响应系统“减少动态效果”并提供暂停/播放控制。
- lib/features/profile/ — profile_screen.dart 退出登录加保护并按顺序调用；profile_settings_screen.dart Token 换号后清理/同步关注标签；profile_favorite_screens.dart 删除仅做透传的 ProfileFollowingScreen。
- lib/features/categories/、lib/features/profile/ — 改为引用 core 的 FollowingTagsButton，消除 feature 间横向 import。
- lib/features/makers/、lib/features/directors/、lib/features/series/ — 改用 core 泛型实体列表屏，保留各自数据源与 tile。
- lib/features/following/index.dart — 移除仅供跨 feature 使用的导出。
- STRUCTURE.md、RULES.md、README.md — 修正 settings feature、路由位置、关注按钮归属与版本/测试数等文档漂移（仅限与本次修复直接相关的行）。
- .github/workflows/compile_apk.yml — 在构建前加入 `dart format --output=none --set-exit-if-changed lib test` 检查步骤。
- lib 与 test 全量文件 — 执行 `dart format` 拉平格式基线（lib 34、test 49 个文件需改动）。

### 删除

- lib/features/settings/ — 应用入口不可达的死代码（index.dart、screens/settings_screen.dart、widgets/setting_item.dart）。
- lib/features/following/widgets/following_tags_button.dart — 上提到 core 后的原文件。

### 不新建

- 不新增第三方依赖、状态管理框架或本地化框架 — 全部修复在现有 provider + ChangeNotifier、dio、media_kit 体系内完成。
- 不新增独立的安全/网络抽象层 — 域名校验与候选遍历复用现有 DomainManager 与拦截器链路。
- 不新增审查报告或中间分析文档 — 结论直接进入 brief 与 spec。

## 来源覆盖

覆盖边界：`docs/reports/review-report.md` 中上列 37 条发现条目（第三章对应小节）及其第五章修复顺序中对应的分组；其余条目为边界外，不读取、不映射。所有条目读取状态均为 complete。

| Source item and location | Read status | Content to preserve | Spec location | Acceptance ID | Coverage status | Reason or replacement |
| --- | --- | --- | --- | --- | --- | --- |
| S1: 3.1 BASE-1 | complete | 全仓 dart format 通过，格式检查纳入 CI | 格式基线 | A26 | covered | 当前需求 |
| S2: 3.2 SEC-1 | complete | 启动请求遍历持久化线路/备用于兜底，不再固定单一域名 | 启动线路自愈 | A1 | covered | 当前需求 |
| S3: 3.2 SEC-2 | complete | 重试标记每请求作用域，`rotate()` 互斥，可多次轮转 | 请求级线路轮转 | A2 | covered | 当前需求 |
| S4: 3.2 SEC-3 | complete | 下发域名校验 scheme/host，丢弃不合规条目 | 下发域名校验 | A3 | covered | 当前需求 |
| S5: 3.3 STATE-1 | complete | 启动装配使用候选域名并在失败后换域重试 | 启动线路自愈 | A1 | covered | 与 SEC-1 同根因 |
| S6: 3.3 STATE-2 | complete | 会话解码容错，坏值删除并按未登录启动 | 会话解码容错 | A4 | covered | 当前需求 |
| S7: 3.3 STATE-3 | complete | logout 先清内存后 best-effort 持久化 | 登出失败安全 | A6 | covered | 当前需求 |
| S8: 3.3 STATE-4 | complete | refreshListenable + redirect 守卫 + 登出 replace | 登录态路由守卫 | A7 | covered | 当前需求 |
| S9: 3.4 DATA-1 | complete | 启动响应非关键字段容错降级 | 启动响应容错 | A5 | covered | 当前需求 |
| S10: 3.4 DATA-2 | complete | 旧版会话/用户解码加保护并清理坏键 | 会话解码容错 | A4 | covered | 与 STATE-2 同根因 |
| S11: 3.5 ARCH-1 | complete | 关注按钮上提 core，删除透传页 | 架构边界收敛 | A23 | covered | 当前需求 |
| S12: 3.5 ARCH-3 | complete | 删除 settings 死代码并修正文档 | 架构边界收敛 | A23 | covered | 当前需求 |
| S13: 3.6 TEST-1 | complete | 注册四分支与 service.register 契约测试 | 测试补齐 | A25 | covered | 当前需求 |
| S14: 3.6 TEST-2 | complete | 演员筛选/信息面板与控制器测试 | 测试补齐 | A25 | covered | 当前需求 |
| S15: 3.6 TEST-3 | complete | CachedImage URL/宽高断言 | 测试补齐 | A25 | covered | 当前需求 |
| S16: 3.7 PERF-2 | complete | 剧照按槽位限高解码且不额外全尺寸 provider | 剧照缩略图解码限制 | A11 | covered | 当前需求 |
| S17: 3.8 ERR-1 | complete | 解包 DioException.error，展示中文 message | 登录注册错误解包 | A17 | covered | 当前需求 |
| S18: 3.8 ERR-2 | complete | 会话解码失败降级未登录并清坏键 | 会话解码容错 | A4 | covered | 与 STATE-2 同根因 |
| S19: 3.8 ERR-3 | complete | 重试标记不粘滞，支持后续再次轮转 | 请求级线路轮转 | A2 | covered | 与 SEC-2 同根因 |
| S20: 3.8 ERR-4 | complete | 统一 userFacingErrorMessage，禁止原始异常作文案 | 统一错误文案 | A15 | covered | 当前需求 |
| S21: 3.8 ERR-5 | complete | 演员详情错误态可重试 | 演员详情错误可重试 | A16 | covered | 当前需求 |
| S22: 3.9 UIUX-2 | complete | 注册/登录表单可滚动，键盘与大字号不溢出 | 表单可滚动 | A18 | covered | 当前需求 |
| S23: 3.9 UIUX-3 | complete | 选中态使用 onPrimary/ColorScheme 角色并暴露 selected 语义 | 选中态可访问性 | A19 | covered | 当前需求 |
| S24: 3.9 UIUX-4 | complete | 名次徽章达到 4.5:1 并补“第 N 名”语义 | 名次徽章可访问性 | A20 | covered | 当前需求 |
| S25: 3.9 UIUX-5 | complete | 轮播响应减少动效并提供暂停/播放 | 轮播动效控制 | A21 | covered | 当前需求 |
| S26: 3.10 PLAY-1 | complete | seek 分母改为进度条自身宽度 | 预告片进度条 seek | A9 | covered | 当前需求 |
| S27: 3.10 PLAY-2 | complete | 可自动隐藏恢复时重启计时器 | 操作层自动隐藏 | A10 | covered | 当前需求 |
| S28: 3.10 PLAY-3 | complete | 剧照缩略图按槽位限高解码 | 剧照缩略图解码限制 | A11 | covered | 与 PERF-2 同根因 |
| S29: 3.11 USER-1 | complete | “我看过的”接入真实接口数据 | “我看过的”真实数据 | A8 | covered | 当前需求 |
| S30: 3.11 USER-2 | complete | Token 换号后清理/同步关注标签 | 换号清理关注缓存 | A22 | covered | 当前需求 |
| S31: 3.11 USER-3 | complete | secure 会话解码兜底 | 会话解码容错 | A4 | covered | 与 STATE-2 同根因 |
| S32: 3.11 USER-4 | complete | 退出登录异常保护且不先清缓存 | 登出失败安全 | A6 | covered | 与 STATE-3 同根因 |
| S33: 3.12 LIST-3 | complete | 缺 total_pages 时按满页推断 | 榜单分页推断 | A12 | covered | 当前需求 |
| S34: 3.12 LIST-4 | complete | 使用服务端 ranking，末页判断收敛 | Top250 名次 | A13 | covered | 当前需求 |
| S35: 3.12 LIST-5 | complete | 滚动监听加 error/hasMore 守卫 | 列表加载失败守卫 | A14 | covered | 当前需求 |
| S36: 3.13 MOD-1 | complete | 三个实体列表收敛为 core 泛型屏 | 实体列表屏收敛 | A24 | covered | 当前需求 |
| S37: 3.13 MOD-3 | complete | 删除 settings 死代码并修正文档 | 架构边界收敛 | A23 | covered | 与 ARCH-3 同根因 |

# 非目标

- 不处理 P2 及其余 35 条发现，包括 29 条“待确认”条目（SEC-4/5/6、STATE-5/6、DATA-3/4/5、ARCH-2/4/5/6、TEST-4/5/6、PERF-1/3/4/5/6、ERR-6、UIUX-1/6、PLAY-4/5/6、USER-5/6、LIST-1/2/6、MOD-2/4/5/6）。
- 不联机验证服务端契约（LIST-1/LIST-2 的 `page`/`type=list`），不做真机/模拟器网络实测与性能 profile。
- 不重构未列入覆盖边界的模块，不调整 UI 视觉风格（除可访问性对比度必需项），不新增功能。
- 不改动 Android/iOS 构建配置、签名、manifest 权限与依赖版本；不触发 `flutter pub get`。
- 不改写 `docs/reports/review-report.md` 本身。

# 验收示例

- A1: 启动请求不再固定单一兜底域名：冷启动时按持久化可用线路（key_baseurl/apiDomains）、备用域名、兜底域名的顺序尝试；主域不可达而本地存在可用线路时能成功进入主页；全部候选失败时仍显示启动失败页，且重试会重新遍历候选而非重复同一 URL。
- A2: 线路轮转按请求生效：同一进程内首次 608/连接错误触发一次轮转，之后新的失败请求仍可再次轮转；并发失败请求只触发一次 `rotate()`（域名列表为 2 时不会双跳回原失效域名）；测试覆盖连续两次轮转。
- A3: 服务端下发域名在应用为 baseUrl 前校验：非 `https` scheme、空 host 的条目被丢弃；全部不合规时保持当前域名不变；合规条目正常生效且不把不合规列表持久化为可用线路。
- A4: 本地会话/用户数据损坏不影响启动：secure storage 或旧 prefs 中的 `key_auth_session`/`key_user` 为畸形 JSON 或非对象时，不抛异常、删除坏键、按未登录继续启动并进入登录引导；新增畸形数据回归测试；`_bootstrap` 区分可重试与不可重试错误。
- A5: 启动响应字段类型漂移不阻断启动：`recent_keywords`/`recent_magnet_keywords` 中的非字符串项被跳过，`settings`/`user` 类型异常降级为空/null，启动仍成功且其余字段可用。
- A6: 退出登录在安全存储写失败时仍能登出：内存 token/user 先清空并通知，持久化失败被捕获记录；个人页退出有异常保护并进入未登录态/首页；会话过期分支的重定向不再被 `isLogged` 拦截。
- A7: 未登录访问 `/profile/**` 由路由重定向到登录页；会话失效被全局踢出时使用 go/replace 清理受保护页，返回键不能回到已登出的受保护页面；认证状态变化会重新求值路由。
- A8: “我看过的”不再指向恒空占位页：使用真实 `status=watched` 数据源，有看过记录时展示影片列表；顶部 Tab 与筛选入口不再共用空 controller/空回调。
- A9: 预告片进度条 seek 以进度条自身宽度为分母：点击/拖动到进度条某位置 seek 到对应比例时长，点击最右端接近视频结尾；尾部填充跟手；新增断言 seek 目标位置的测试。
- A10: 播放操作层在缓冲/暂停恢复后重新开始自动隐藏计时；初始即处于缓冲的场景在恢复播放后也能自动隐藏；手动唤起后同样按规则隐藏。
- A11: 剧照缩略图按槽位高度×DPR 限制解码尺寸（memCacheHeight 等），宽高比测量复用同一有界 provider 或使用已记忆比例；全屏图库仍按原图展示。
- A12: 榜单响应缺少 `total_pages` 时按“本页满页则 totalPages=page+1，否则 page”推断，有码/无码/欧美/FC2 榜单可加载第 2 页；服务端 `current_page` 前移时当前页判断仍正确。
- A13: Top250 使用服务端返回的 `ranking` 渲染名次（`ignore_watched` 过滤后名次可跳号且不再被改写为连续编号）；末页判断按 start_rank 上限或 total 收敛，短页不提前截断。
- A14: 加载更多失败后，`PaginatedListView`、`MovieGridView`、`ActorGridView` 的滚动监听在 `error != null` 或 `hasMore == false` 时不再自动重发请求；仅用户点击“重试”按钮才重新请求。
- A15: core 提供统一的 `userFacingErrorMessage(Object error)`：ApiException 显示服务端中文 message，连接/超时显示“网络连接失败，请检查网络”，其余显示“加载失败，请重试”；所有 ErrorRetryWidget 调用点与首页分区错误不再展示 DioException 原始英文串。
- A16: 演员详情加载失败时展示中文错误文案与重试按钮，点击后重新加载；重试开始时错误态被重置，成功后正常展示内容。
- A17: 登录/注册失败时展示服务端中文 message 而非 DioException 技术串（不再出现 “DioException [bad response]” 前缀）；响应缺少 token/user 时给出明确中文提示且不抛 TypeError；新增断言错误文案的测试。
- A18: 注册页与登录页表单可滚动：键盘弹起或系统大字号时内容可滚动到提交按钮，不再出现 RenderFlex overflow，错误提示可见。
- A19: 演员卡选中态使用 `colorScheme.onPrimary` 等语义色，暗色主题下勾选图形对比度达到非文本 3:1；Semantics 暴露选中状态。
- A20: 名次徽章前景/底色对比度达到 4.5:1（或采用等效深色前景方案），读屏朗读包含“第 N 名”。
- A21: 首页推荐轮播在系统开启“减少动态效果”时不自动切换；提供用户可操作的暂停/播放控制；现有触摸暂停与滚动行为不回退。
- A22: 通过认证 Token 弹窗换号后，关注标签缓存被清空或按新账号同步；冷启动不再把上一账号的标签作为 batch_push 推给新账号。
- A23: feature 之间不再存在横向 import（categories/profile 不再 import following）：关注按钮位于 core；仅做透传的 ProfileFollowingScreen 删除且路由直连 FollowingScreen；lib/features/settings/ 死代码删除；STRUCTURE.md/RULES.md 相关描述与实际一致。
- A24: 片商/导演/系列复用同一个 core 泛型“Tab + 分页列表”屏；TabController 长度取自 children 长度；三个页面的加载/空态/错误/分页行为与改动前一致。
- A25: 测试补齐且有效：注册页覆盖两次密码不一致、密码过短、接口报错、成功跳转（含 from）四个分支；注册 API 测试直接调用 `AuthSessionService.register` 并断言提交字段；演员详情覆盖筛选 tags/sort/order 参数与信息面板占位符；CachedImage 测试断言 imageUrl、width、height 与域名前缀。
- A26: 全仓 `dart format --output=none --set-exit-if-changed lib test` 退出码 0；CI 构建流程包含该格式检查步骤；逻辑改动与纯格式改动在提交中可区分。

# 约束与不变量

- 依赖管理：不新增依赖包；不运行 `flutter pub get`（本机会重写 lock），所有 flutter 命令带 `--no-pub`。
- 既有用户可见行为保持不变：除 A1–A26 明确修正的行为外，列表、详情、播放、登录、收藏、主题、关注等交互不回退。
- 安全基线：会话继续保存在 `flutter_secure_storage`；日志脱敏范围只增不减；明文 token 不得出现在日志或 SharedPreferences；Token 只发往通过校验的 https 域名。
- 播放链路：预告片操作层的显隐同步、长按 2x、亮度/音量滑动、整屏横向 seek 等既有手势行为不变。
- 测试基线：禁止 skip 测试；既有 1005 个用例保持通过；新增回归测试必须在修复前可复现问题、修复后通过。
- 架构基线：遵循 RULES.md（feature 只依赖 core）与 STRUCTURE.md；公共能力上提 core，跨 feature 复用经 index/公共模块。
- 文档基线：只修正与本批修复直接相关的文档行，不重写文档结构。

# 决策

- 修复范围取报告“立即修 + 本迭代”（P0+P1，37 条），不含 29 条待确认与 6 条 P2 已复核低危；待确认条目留待后续独立复核批次。
- BASE-1 执行全仓格式化，并在 CI 构建流程加入格式检查；格式化与逻辑改动分开提交。
- 启动自愈优先复用 DomainManager 的候选列表（持久化线路 → 备用域名 → 兜底域名），而不是在 StartupApiClient 内另建一套状态；SEC-3 校验后的列表才允许持久化。
- 轮转重试标记放入 `RequestOptions.extra`，`rotate()` 用互斥标志串行化，保持“原请求最多重试 1 次”。
- 会话解码容错采用与 `following_tags_store` 相同的降级策略（坏值删除 + 按空/未登录继续），并让 `_bootstrap` 区分可重试（网络）与不可重试（解码/配置）错误。
- 登录/注册错误统一经 `DioException.error` 解包 ApiException，并以 `userFacingErrorMessage` 作最终兜底，避免页面各自拼接文案。
- “我看过的”直接复用 `ProfileReviewMoviesScreen(title: '我看过的', status: 'watched')`，与“我想看的”保持一致，不改造占位页。
- 剧照解码：`ImageSizeListener` 复用带 memCache 的展示 provider（等比缩放不改变宽高比），避免无界解码；全屏图库不受影响。
- Top250 名次以服务端 `ranking` 为准；缺失时回退 startRank+index，末页判断改为 startRank 上限或 total 收敛。
- 架构收敛：FollowingTagsButton 上提 core、删除 ProfileFollowingScreen、删除 settings 死代码；片商/导演/系列抽 core 泛型屏，保留各 feature 数据源与 tile。
- Build 使用动态 workflow 并行实施：按模块/文件所有权分组（启动网络、认证会话、播放器、列表榜单、错误与 UI、架构与测试），组间不共享可写文件；汇总后由主会话完成集成检查与候选提交。
- 不启用 Comet Supervisor 子 change 分解：26 条验收项共享同一集成候选与同一套 analyze/test/format 检查，拆分会重复建 worktree、重复验证且增加合并成本；并行度由 Build 内的动态 workflow 提供。

# 验证预期

- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub`：全量通过（含新增回归测试）。
- `dart format --output=none --set-exit-if-changed lib test`：退出码 0。
- A1/A2/A3/A5/A12/A13/A22 通过新增或扩展的单元测试验证（域名候选遍历、连续轮转、下发校验、启动解析容错、分页推断、ranking 解析、换号清理）。
- A4/A6/A17 通过 auth_provider/登录注册 widget 测试验证（畸形会话、写失败 fake、错误文案断言）。
- A7/A8/A16 通过路由与 widget 测试/实现审查验证（redirect、真实数据源、重试回调）。
- A9/A10/A11/A14/A21/A24 通过 widget/单元测试与实现审查验证（seek 目标、计时器重启、memCache 参数、滚动守卫、动效开关、泛型屏行为）。
- A15/A19/A20 通过实现审查与语义/对比度断言验证。
- A23 通过 grep 断言（无 feature 间横向 import、无 features/settings 引用）与文档一致性检查验证。
- A26 通过确定性命令与 CI 配置审查验证。
- 真机/联机行为（启动域名实况、服务端 ranking/总页数）不在本批验证范围，由单元测试与实现审查覆盖。

# 待解决问题

（无）
