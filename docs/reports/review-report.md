# Jade 项目多维度审查报告

> 本报告仅汇总工作流提供的确定性基线与多路审查/复核材料，未新增发现；所有代码位置、证据与数字均沿用材料原文。除工作流给定的基线外，报告撰写阶段未执行任何
> flutter/dart/test 命令；凡涉及运行结果的表述，均明确标注为“基线给定”。

## 一、审查概览

### 1.1 范围

- 审查对象：Jade Flutter 客户端仓库（当前分支 dev，工作区干净）。
- 覆盖 13 个维度：工程基线、安全与网络层、状态管理与启动装配、数据模型与序列化、架构与规范合规、测试质量与覆盖、性能与资源生命周期、错误处理与健壮性、UI
  一致性与可访问性、播放器与详情页、个人中心与会话、首页/搜索/分类浏览、其余模块与可维护性。
- 材料构成：12 路分维度静态审查 + 1 组确定性工具链基线 + 对 43 条发现的独立代码级复核（另有 29
  条未进入复核预算）。

### 1.2 方法与证据规则

- 各维度审查以只读方式阅读源码为主，辅以 grep/rg/sed 定位；部分条目对照了 Flutter SDK 与第三方包源码（Flutter
  3.44.8、dio 5.10.0、flutter_slidable 4.0.3、carousel_slider 5.1.2、material_color_utilities 0.13.0）。
- 复核员逐条回到代码核对行号、调用链与测试覆盖；本报告撰写阶段未再执行任何命令。
- 严重度沿用各维度原始定级；同一缺陷在不同维度给出不同定级时，报告中两者都保留，并在修复顺序中按较高定级优先处理。

### 1.3 确定性基线（工作流实际执行结果，本报告未重跑）

| 检查          | 命令                                              | 结果                                                           |
|---------------|---------------------------------------------------|----------------------------------------------------------------|
| 静态分析      | `flutter analyze --no-pub`                        | 0 个问题，退出码 0                                             |
| 单元/组件测试 | `flutter test --no-pub`                           | 1005 个测试全部通过，退出码 0                                  |
| 格式检查      | `dart format --output=none --set-exit-if-changed` | lib 34/249、test 49/157 个文件需格式化（只报告，未写入文件）   |
| 行覆盖率      | 与测试同一次运行                                  | 89.2%，8078/9051 行，覆盖 225 个文件（其中 lib 源文件 212 个） |

行覆盖率低于 75% 的 lib 文件（12 个）：

| 文件                                                         | 行覆盖率 |
|--------------------------------------------------------------|----------|
| lib/features/movie_detail/widgets/save_to_list_sheet.dart    | 73%      |
| lib/features/profile/screens/collected_entities_screen.dart  | 64%      |
| lib/core/services/collections_service.dart                   | 74%      |
| lib/features/auth/screens/register_screen.dart               | 41%      |
| lib/features/actors/widgets/actor_info_sheet.dart            | 0%       |
| lib/features/movie_detail/services/detail_section_state.dart | 73%      |
| lib/features/profile/screens/collected_lists_screen.dart     | 65%      |
| lib/features/actors/widgets/actor_movie_filter_sheet.dart    | 0%       |
| lib/core/device/login_device_info_service.dart               | 50%      |
| lib/features/actors/services/actor_movie_controller.dart     | 49%      |
| lib/features/articles/widgets/article_cover_image.dart       | 60%      |
| lib/main.dart                                                | 64%      |

完全没有覆盖的 lib 文件：lib/features/actors/widgets/actor_info_sheet.dart（75
行）、lib/features/actors/widgets/actor_movie_filter_sheet.dart（58 行）。

### 1.4 发现计数

| 维度                 | 发现数 | 高    | 中     | 低     |
|----------------------|--------|-------|--------|--------|
| 工程基线             | 1      | 0     | 0      | 1      |
| 安全与网络层         | 6      | 2     | 1      | 3      |
| 状态管理与启动装配   | 6      | 1     | 3      | 2      |
| 数据模型与序列化     | 5      | 0     | 2      | 3      |
| 架构与规范合规       | 6      | 0     | 2      | 4      |
| 测试质量与覆盖       | 6      | 0     | 3      | 3      |
| 性能与资源生命周期   | 6      | 0     | 1      | 5      |
| 错误处理与健壮性     | 6      | 1     | 4      | 1      |
| UI 一致性与可访问性  | 6      | 0     | 4      | 2      |
| 播放器与详情页       | 6      | 1     | 2      | 3      |
| 个人中心与会话       | 6      | 1     | 2      | 3      |
| 首页、搜索与分类浏览 | 6      | 0     | 3      | 3      |
| 其余模块与可维护性   | 6      | 0     | 1      | 5      |
| **合计**             | **72** | **6** | **28** | **38** |

复核状态： **43 条已复核（verified，独立复核员已在代码中证实）**， **29
条待确认（unconfirmed，未证实或未纳入复核预算）**。

## 二、总体结论

1. **最优先：启动与线路自愈链路存在单点失效。**
   启动请求固定打兜底域名、完全不经过域名轮转（SEC-1、STATE-1）；而唯一的轮转拦截器又把“是否已重试”标记保存在实例字段上、进程内只能轮转一次且并发时可能双跳（SEC-2、ERR-3）。主域名被墙是这个应用设计上假设的常态，当前实现却会在冷启动和首次轮转之后失去自救能力，用户只能停在启动失败页或持续加载失败直到杀进程重启。
2. **其次：多处明确的用户可见功能错误。** 「我看过的」仍指向恒定返回空页的占位页（USER-1，高）；预告片进度条的
   seek 用整屏宽度作分母，后段无法定位（PLAY-1，高）；登录/注册对 ApiException 的捕获不可达，失败时展示
   DioException 英文技术串（ERR-1，高）；公开榜单缺 `total_pages` 时退化到只加载第一页（LIST-3），Top250
   按位置推算名次、忽略服务端 `ranking`（LIST-4）。这些不是风格问题，而是功能与文案的直接错误。
3. **第三：启动期的“严格解码”会把一次坏数据变成永久启动失败。** 本地会话/用户键、启动响应中的热词与
   settings/user
   都做过强转，任一格式漂移即抛异常，而失败页只有“重试”且从不清理坏值（STATE-2/DATA-2/ERR-2/USER-3、DATA-1）。触发概率不高，但后果不可恢复、修复成本极低，应与
   P0 一并处理。
4. 其他值得注意的系统性问题是测试的“假安全”与格式基线漂移：1005
   个用例全绿，但注册提交链路、演员筛选/信息面板、存入清单失败回滚等关键分支零覆盖，CachedImage 三条名为
   URL/尺寸的测试实际只断言 widget 存在（TEST-1/2/3/5）；同时 `dart format` 有 34+49
   个文件未通过（BASE-1），说明提交约定与现状已脱节。

## 三、分维度结论

### 3.1 工程基线

静态质量门槛通过：analyze 0 问题、1005 个测试全部通过、行覆盖率 89.2%，整体处于健康区间。但格式检查未纳入门槛：lib
与 test 分别有 34 个、49 个文件需要重新格式化，与“提交前执行 dart format”的项目约定不一致；覆盖率另有
12 个文件低于 75%、2 个文件完全为 0，主要集中在注册、演员弹窗、收藏实体页与启动装配。

**BASE-1｜严重度：低｜复核状态：已复核（确定性命令直接判定）**

- 位置：整个仓库（lib 与 test）
- 问题：`dart format` 检查未通过——lib 有 34 个、test 有 49 个文件需要重新格式化。
- 影响：格式漂移会在 CI 未纳入格式检查时持续累积；项目交互约定要求提交前执行 dart
  format，说明约定与现状不一致，后续改动会夹带无关格式 diff。
- 证据：`dart format --output=none --set-exit-if-changed lib` → 退出码 1（34/249 需改）；test → 退出码
  1（49/157 需改）。`--output=none` 只报告不写入，工作区保持干净。
- 建议：确认团队使用的 Dart 版本后统一执行 `dart format`，并把该检查纳入 CI。
- 说明：本条由确定性命令直接判定，无需代码复核。

### 3.2 安全与网络层

网络与安全层整体骨架健康：Token 已迁到 `flutter_secure_storage`
并保留旧明文迁移清理（auth_provider.dart:28-56 与 `_removeLegacySession`
），登录/注册/改密请求体做了整段脱敏，签名与鉴权拦截器链路正确；Android 侧 `allowBackup=false`、无
`network_security_config`、无非 https 常量，`res/xml` 目录不存在（android/app/src/main/res/xml 缺失，未构建验证
targetSdk，仅读到 build.gradle.kts 继承 `flutter.targetSdkVersion ≥ 28`，cleartext
默认关闭）。真正的问题集中在域名降级状态机：启动请求完全绕过轮转、重试标记是进程级粘滞状态，导致首次线路被封后无法继续自愈；其次是对服务端下发的域名列表零校验，以及
failover 重试把错误包成丢失 response 的 DioException。本维度为只读审查，未运行工具链命令。

**SEC-1｜严重度：高｜复核状态：已复核（代码级）**

- 位置：lib/core/network/startup_api_client.dart:21
- 问题：启动接口使用独立 Dio，`baseUrl` 硬编码为 `fallbackBaseUrl` 且未接入域名轮转，每次冷启动都只打主域名。
- 影响：主域名被墙/不可达时（应用默认 jdforrepam.com 本身即最易被封的域名），`StartupProvider.load`
  必然失败，StartupScreen 拒绝跳转（startup_screen.dart:32-33），用户被永久停在“启动失败”页，点“重试”仍请求同一个
  URL；即使本地已通过 `DomainManager.load` 恢复了上次可用的备用域名（domain_manager.dart:
  50-58），启动阶段也完全不会使用。这使“域名轮转”在最需要它的场景（冷启动）失效。
- 证据：startup_api_client.dart:19-30 `Dio(BaseOptions(baseUrl: AppConstants.fallbackBaseUrl, ...))`
  ，拦截器只有 Signature/ResponseLogging/Response，没有 DomainSwitchInterceptor；main.dart:95 使用
  `StartupApiClient.create()`，传入的 domainManager 仅用于 `applyStartup` 结果（startup_provider.dart:
  72-73）；app_router.dart:31 `initialLocation = AppRoutes.startup`；startup_screen.dart:32-33
  `if (!succeeded || !mounted) return;`，失败页只有重试（:86-89）。BackupDomains 的 `backupUrls`/
  `permanentAppDomain`/`unblockAppDomain`（startup.dart:11-23）在 lib/ 下无任何生产消费方（grep
  仅命中模型、.g.dart 与 test/core/network/backup_domains_decryptor_test.dart:25-31）。
- 建议：让启动请求复用 DomainManager 的候选列表（持久化 apiDomains + backupUrls +
  fallback）依次尝试，或至少在主域名失败时回退到 `key_baseurl` 中持久化的可用域名。
- 复核说明：逐处核对成立。 (1) 文档也支持这是偏离：docs/main/api/api-reference.md:42 状态机为“读取
  key_baseurl，缺省 jdforrepam.com → 请求 startup”，:10 写明 jdforrepam.com 仅首次安装/无 key_baseurl
  时使用。 (2) “永久停在失败页”是条件性的——固定启动域名不可达且本地存有可用域名时，App
  内确实无自救路径，因为线路选择入口需要先进主页（profile_settings_screen.dart:246-248）。 (3) 原证据中
  app_router.dart:29 应为 :31，属行号笔误。

**SEC-2｜严重度：高｜复核状态：已复核（代码级）**

- 位置：lib/core/network/interceptors/domain_switch_interceptor.dart:42
- 问题：防重试标记 `_retried` 是拦截器实例字段，置 true 后全进程不再重置，导致整个 App
  生命周期只允许轮转一次；且该检查在首个 await 之前执行，并发的失败请求可以同时通过并各自调用一次
  `rotate()`。
- 影响：第一次 608/连接错误轮转成功后 `_retried` 永久为 true（:32 直接 `handler.next(err)`
  ），此后新域名再被封也不再轮转，用户只能看到加载失败直到重启 App；域名列表为 2
  个时，并发双跳会绕回原来那个已失效的域名重试，首次故障就表现为仍不可用。文档明确期望“原请求最多重试 1
  次”（按请求）与“后续请求恢复 608 自动轮转”，实现与二者都不符。
- 证据：domain_switch_interceptor.dart:12 `bool _retried = false;`、:32
  `if (_retried || !_shouldRotate(err))`、:42 `_retried = true;`；全仓库 grep 该符号仅此三处，无任何重置路径；拦截器由
  api_client.dart:45 在启动时创建一次（main.dart:
  77）并长期存活。docs/superpowers/specs/2026-08-05-line-switch-design.md:70“ApiClient.swapBaseUrl
  (主域名)，后续请求恢复 608 自动轮转”；docs/main/api/api-reference.md:50“原请求最多重试 1 次”。测试
  domain_switch_interceptor_test.dart 全部 6 个用例只覆盖单次轮转，未覆盖“轮转后再次 608”。
- 建议：把重试标记放进 `RequestOptions.extra`（每请求一次），并在重试结束/失败后清除；同时对 `rotate`
  加互斥（同步标志位或 Future 串行化）避免并发双跳。
- 复核说明：成立。拦截器唯一装配点是 api_client.dart:45，`ApiClient.create` 仅在 main.dart:77 调用一次；
  `applyStartup`/`swapBaseUrl` 只改 baseUrl，不重置该标志。

**SEC-3｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/network/domain_manager.dart:77
- 问题：解密得到的 `apiDomains` 未经任何 scheme/host 校验就直接作为全局 baseUrl，随后所有请求都携带
  Bearer Token。
- 影响：域名列表来自 startup 响应中 AES-CBC 解密的 `backup_domains_data`（密钥硬编码且无完整性校验），
  `applyStartup` 直接取 `_apiDomains.first` 作为 Dio baseUrl；一旦响应被篡改（TLS
  被绕过/代理劫持/服务端被攻破）或字段异常，客户端会把 `Authorization: Bearer <token>`
  发往攻击者指定的主机；若条目缺少 `https://` 或为空串，则全站请求立即失败且仅能靠轮转逃生。属于缺少纵深防御的信任边界问题。
- 证据：domain_manager.dart:71 `_apiDomains = List<String>.from(data.apiDomains);`、:77
  `_currentUrl = _apiDomains.isNotEmpty ? _apiDomains.first : _currentUrl;`，`select()`/`load()`
  同样无校验（:60-63、:53-58）；auth_interceptor.dart:14-18 在 token 非空时写入 `authorization: Bearer`
  ，不区分目标主机；domain_switch_interceptor.dart:43 直接把该值写入 `dio.options.baseUrl`
  ；backup_domains_decryptor.dart:13-14 硬编码 AES key/IV、:19-23 解密后直接 `fromJson`，无 MAC/HMAC。
- 建议：`applyStartup`/`select` 前用 `Uri.tryParse` 校验 scheme 为 https、host
  非空（可选下发域名前缀白名单），丢弃不合规条目，全部不合规时保持当前域名。
- 复核说明：成立。限速因素：兜底域名是 https，且未覆写 `badCertificateCallback`/`SecurityContext`，利用需先突破
  TLS 信任或服务端被攻陷；但 AES 密钥硬编码在公开源码中可静态取得，且 `_persist` 会把坏列表写回本地，故非纯理论问题。

**SEC-4｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/core/network/interceptors/response_logging_interceptor.dart:95
- 问题：登录成功响应体（含 JWT）在 debug 日志中明文输出，脱敏只覆盖了请求体与 candidate-token 请求。
- 影响：日志中会出现完整的 access token 与用户对象，任何读取 debug
  日志的途径（logcat、IDE、崩溃收集）都能直接拿到可复用的登录凭据；发布包不受影响（`_enabled` 默认
  `kDebugMode`），因此定为低危。
- 证据：response_logging_interceptor.dart:12 `_enabled = enabled ?? kDebugMode`、:95
  `AuthRequestContext.hasSensitiveResponseBody(options) ? _redactedResponseBody : _compactJson(...)`
  ；auth_request_context.dart:11-17 该标志仅由 `candidateTokenOptions` 设置；登录走普通
  `_api.post(Endpoints.sessions, data: FormData...)`（auth_session_service.dart:26-35），响应 token 在
  login_screen.dart:88 读取。
- 建议：对 `/api/v1/sessions`、`/api/v1/users` 的成功响应同样脱敏，或只记录 success/action 等非敏感字段。

**SEC-5｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/core/network/interceptors/domain_switch_interceptor.dart:52
- 问题：轮转后的重试失败被重新包装成 `DioException(type: badResponse)`，丢掉 response
  与原始错误类型，ApiException 被埋进 `error.error`。
- 影响：凡是在轮转期间失败过一次的请求，调用方按 `error.response?.statusCode == 401` 或 `err.type`
  做分支都会失效（response 为 null）；登录页的 `on ApiException catch` 也不再命中，会落到通用 catch
  把“DioException [badResponse]: ...”显示给用户。属于网关层错误契约不自洽，会让鉴权/重试判定在故障时段静默走错分支。
- 证据：domain_switch_interceptor.dart:51-56
  `catch (e) { handler.next(DioException(requestOptions: err.requestOptions, error: e, type: DioExceptionType.badResponse)); }`
  （无 response 字段）；受影响调用方如 session_refresh_service.dart:56、movie_detail_screen.dart:342 依赖
  `error.response?.statusCode == 401`，login_screen.dart:119 依赖 `on ApiException`。
- 建议：直接 `handler.next(e is DioException ? e : err)`，或在包装时保留原 response 并把 ApiException
  解包到 error 字段。

**SEC-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/core/network/api_client.dart:36
- 问题：只设置了 connectTimeout/receiveTimeout，没有 sendTimeout，上传类请求可能无限挂起。
- 影响：登录（FormData multipart）、收藏/清单动作、影片操作都用 FormData 上传（auth_session_service.dart:
  28、collections_service.dart:163、movie_detail_service.dart:130）；若连接建立后服务端不再读取请求体或链路半开，Dio
  5 中 sendTimeout 默认为 null，该请求没有超时保护，UI 会一直停在 loading 且不会进入域名轮转（不会产生
  DioException），只能杀进程。
- 证据：api_client.dart:34-39 BaseOptions 仅包含 baseUrl/connectTimeout (15s)/receiveTimeout (20s)
  ，其余字段取默认；startup_api_client.dart:20-24 同样缺 sendTimeout。
- 建议：补充 `sendTimeout`（如 30s），并核对 receiveTimeout 语义是否覆盖上传阶段。

### 3.3 状态管理与启动装配

状态管理骨架整体健康：provider 职责单一、没有未释放的流订阅/监听器（grep
addListener/StreamSubscription/Timer 在
lib/main.dart、lib/app.dart、lib/router、lib/core/providers、lib/core/services、lib/core/storage
下零命中），会话刷新四条分支都有测试，且 refresh 用例通过 `candidateTokenOptions` 抑制了全局
onAuthError，避免了双登出。问题集中在启动装配的失败面与登出路径的失败安全：startup
请求被固定在兜底域名、持久化数据解码无容错而失败页只会无限重试、logout
先写后清内存导致写失败时无法登出、认证状态变化不参与路由判定。另检查了 flutter_secure_storage
的迁移逻辑（明文→secure、tombstone、迁移失败保留明文重试）实现正确，但写入失败的下游处理不完整；AndroidManifest
未声明任何 VIEW intent-filter，iOS 目录不存在，因此“深链”在发布形态下没有外部入口，只涉及内部路由。本维度未运行
analyze/test/format，基线取自任务给定值。

**STATE-1｜严重度：高｜复核状态：已复核（代码级）**

- 位置：lib/main.dart:95
- 问题：启动装配把 startup 请求固定在 `AppConstants.fallbackBaseUrl`
  ，完全忽略已持久化线路和用户在设置里手选的线路，失败后重试也仍打同一域名（与 SEC-1 同一根因，此处从装配层补充）。
- 影响：当兜底域名在用户网络下不可达（应用本身为此设计了多域名轮转和手动线路选择）时，
  `StartupProvider.load()` 必然失败，StartupScreen
  只渲染错误文案+重试按钮且没有跳过入口（startup_screen.dart:32-34 失败即 return，75-94
  只有重试），用户无法进入任何页面，重试永远不会换域名。
- 证据：main.dart:95 `startupApi: startupApi ?? StartupApiClient.create()`；startup_api_client.dart:21
  `baseUrl: AppConstants.fallbackBaseUrl`，26-30 只挂 Signature/Logging/ResponseInterceptor，没有
  DomainSwitchInterceptor（对比 api_client.dart:40-46 挂了轮转拦截器）；domain_manager.dart:60-63
  已把手选/持久化线路恢复为 currentUrl，但它只被 ApiClient 使用（profile_settings_screen.dart:370
  选中后调用 `ApiClient.instance.swapBaseUrl`）；app_constants.dart:8-9 注释自述兜底值“startup API
  返回后会被动态覆盖”，即 startup 本身被排除在动态域名之外。
- 建议：让 `StartupApiClient.create` 接受 `DomainManager.currentUrl` 或候选域名列表，并在 `load()`
  失败后遍历已持久化的 `apiDomains` 重试。
-
复核说明：事实成立。需澄清：该固定域行为是设计文档的硬性要求（docs/superpowers/plans/2026-07-28-startup-domain-bootstrap.md:
17-24 要求 baseUrl 固定为 fallbackBaseUrl、不得读取历史业务域名），因此属规格层面的可用性缺陷而非实现偏离；但
2026-08-05
线路切换设计承诺手选线路“重启后保持”（docs/superpowers/specs/2026-08-05-line-switch-design.md:
5-7），持久化的可用线路在 startup 阶段被完全绕过，用户自救路径被切断。

**STATE-2｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/providers/auth_provider.dart:36
- 问题：启动路径对持久化会话/用户的解码没有任何 try/catch，一旦存储值非法就抛异常，而 `_bootstrap`
  把所有初始化异常都当作可重试错误，导致永久停在错误页。
- 影响：`key_auth_session`（secure 或旧明文 prefs）或 `key_user` 被写坏、被外部改写为非法 JSON、或为合法
  JSON 但非对象时，`AuthProvider.create` 抛 FormatException/TypeError → `_buildEntry` 抛出 →
  main.dart:53-56 `runApp(StartupFailureScreen(error, onRetry: _bootstrap))`
  ，重试只是重复同一确定性失败，页面展示原始异常文本，用户只能清除应用数据才能恢复。
- 证据：auth_provider.dart:29-38 的 try 只包住 `secure.read`，36 行的 `jsonDecode(stored)` 在 try
  之外；74 行 `_restoreSession(jsonDecode(encoded))`、48 行 `jsonDecode(u) as Map<String, dynamic>`
  同样无保护；main.dart:49-59 的 catch 不区分错误类型并原样把 `_bootstrap` 作为
  onRetry。对照项目自身约定：following_tags_store.dart:24-32 对同类持久化 JSON 明确按“畸形 JSON
  视作空列表，避免启动崩溃”降级；auth 的 secure read 本身也做了兜底（:29-34）。测试只覆盖格式正确的迁移/墓碑场景，未覆盖畸形数据。
- 建议：把两处 jsonDecode 及 `as Map` 转换包进 try/catch，失败时删除坏值并按“未登录”继续启动；同时让
  `_bootstrap` 区分可重试（网络）与不可重试（解码/配置）错误。
- 复核说明：核心事实成立。需修正：`_restoreSession`（58-66 行）是 if-case 模式匹配 + `Object?` 参数，合法
  JSON 但非对象（如 123、[1]）只会匹配失败、不会抛 TypeError；TypeError 仅发生在 48 行 legacy `key_user`
  的 `as Map` 转换。畸形 JSON 的 FormatException 在三条路径均成立。损坏值可达性有据：git 历史显示旧版本曾写入明文
  `key_auth_session` 与 `key_user`，老设备升级后残留值仍在启动路径被解码。

**STATE-3｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/providers/auth_provider.dart:114
- 问题：`logout()` 先 await 写 tombstone、写成功后才清内存并通知，写异常直接向上抛，导致“退出登录”在安全存储写失败时永久无效，而调用方已提前清掉了其他本地状态。
- 影响：secure 写失败时内存 token 仍在（`isLogged` 仍为
  true），用户按了退出登录却不跳转也无提示；profile_screen.dart:126-139 在此之前已 `clearPassword()` 并
  `FollowingTagsProvider.clear()`，即保存的密码和关注标签缓存被清空但会话仍在。startup_screen.dart:
  53-61 的 expired 分支也依赖 logout 成功：写失败时 `isLogged` 仍为 true，app_router.dart:74-76 会把
  `go('/login?reason=expired')` 重定向回 /home，“登录已过期”提示永远不出现。
- 证据：auth_provider.dart:114-120
  `await _persist({'token': null,'user': null}); _token = null; _user = null; notifyListeners();`
  ；109-111 注释明确“写入失败时内存态未变更，异常原样传播”（该策略对 login 合理，对 logout
  不是）；profile_screen.dart:130-138 无整体 try/catch；session_refresh_service.dart:67-73
  `_logoutBestEffort` 吞掉异常仍返回 expired，于是继续走上面的重定向环路。
- 建议：logout 改为先清内存并 `notifyListeners`（保证内存态登出），再 best-effort 写 tombstone
  并捕获异常记录日志；profile 的退出流程再加 try/catch 兜底跳转首页。
- 复核说明：成立。补充：profile_screen.dart:130-134 确有 try/catch，但只包 `clearPassword()`，113
  行注释所称“写入失败时内存态未变更”的策略在 logout 场景有害；持久化侧也确实是“永久无效”，写失败时旧会话未被覆盖，下次启动会重新读回并恢复登录。

**STATE-4｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/router/app_router.dart:355
- 问题：`_AuthGuard` 只在 initState 的 postFrame 里判一次 `isLogged`，GoRouter 也没有
  `refreshListenable`，认证状态变化不会重新求值路由，登录页又是 push 上去的，登出后受保护页面仍留在栈里可通过返回键回去。
- 影响：会话失效被全局 onAuthError 踢到登录页后，用户按返回键（login_screen.dart:137-142
  `PopScope canPop: true`）会回到刚被登出的受保护页面，该页继续用已为 null 的 token 发请求 → 401 →
  onAuthError 再次 logout（重复写 secure storage）+ `goLoginForAuthError` 再次 push
  登录，形成“返回一次又被弹回”的往返；期间页面还展示上一会话已加载好的内容。
- 证据：app_router.dart:31-38 GoRouter 只传 initialLocation/redirect/routes，无
  refreshListenable；355-364
  `addPostFrameCallback(... if (!mounted || auth.isLogged) return; context.push('${AppRoutes.login}?from=...'))`
  是一次性判断；49-62 `goLoginForAuthError` 使用 `router.push`（叠加而非替换）；main.dart:80-84
  onAuthError 只做 logout+push，没有清理导航栈。
- 建议：给 GoRouter 传 `refreshListenable: auth`，并把“未登录不得进入 /profile/**”下沉到 redirect 按
  matchedLocation 判定；全局登出用 go/replace 而不是 push。
- 复核说明：成立。两处需精确：a) “返回后该页继续发请求”并非返回即自动发生，受保护页多为 initState
  一次性拉取，需要用户滚动分页/切 Tab/下拉刷新等动作才会触发下一次 401；b)
  “继续展示上一会话内容”不适用于所有页，profile_recent_viewed_screen.dart:46-56、89-107 会在
  `isLogged=false` 时切换为 LoginGuideCard，但清单/收藏等页无此监听，确实保留旧内容。

**STATE-5｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/main.dart:93
- 问题：`FollowingTagsProvider.initialize()` 被 `unawaited` 掉，而 initialize 在 await 之后无条件覆盖
  `_tags` 且没有并发去重，`syncFromRemote()`/`clear()` 都不等待初始化完成。
- 影响：若 initialize 的本地读取晚于 syncFromRemote（远程权威列表）或 clear（登出清空）完成，旧缓存会覆盖新结果，之后一次
  batchPush 还会把旧列表推回服务端；并发调用两个 initialize 都会通过 `if (_initialized) return`
  各跑一遍。当前 `PrefsFollowingTagsStore.load` 内部没有真实
  I/O、几乎必然先于网络返回，所以只在注入异步存储或改动实现后才显现，属于结构性脆弱点。
- 证据：main.dart:93 `unawaited(followingProvider.initialize());`；following_tags_provider.dart:30-35
  `if (_initialized) return; _tags = await _store.load(); _initialized = true;`（await 后无条件赋值，无
  in-flight future 复用）；startup_screen.dart:64-67 在 refresh 成功后直接 `await ...syncFromRemote()`
  ，其 65-75 以当时 `_tags` 作为 batchPush 内容；`clear()`（78-82）也是先等 `_store.clear()` 再改
  `_tags`。
- 建议：把 initialize 改成缓存同一个 Future（或暴露 ready Future），并让
  syncFromRemote/syncFromLogin/clear 在开始时 await 该 Future。

**STATE-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/core/providers/following_tags_provider.dart:42
- 问题：多个状态变更方法都是“先改字段 → await 持久化 → 再 notifyListeners”，持久化抛错时内存已变更但监听者永远收不到通知。
- 影响：SharedPreferences 写失败时 `_tags` 已包含新关注项、`isFollowing()` 返回
  true，但按钮/列表因未通知仍显示未关注，用户再点会走 unfollow 分支；同时 categories_screen.dart:
  145-156 的 catch 会提示“操作失败，请重试”，与实际服务端结果相反。同类问题见 settings_provider.dart:
  23-36。触发条件为写入失败，概率低但状态会持续不一致。
- 证据：following_tags_provider.dart:42-46
  `final item = await _dataSource.follow(...); _tags = [item, ..._tags]; await _persist(); notifyListeners();`
  ；51-54 unfollow、58-61 syncFromLogin、78-82 clear 同构；84 `_persist() => _store.save(_tags)`
  直接抛错；settings_provider.dart:23-27、31-36 同构。
- 建议：改为改字段后立即 `notifyListeners()`，持久化用 try/catch 记录日志并与内存状态解耦（或至少把
  notify 放进 finally）。

### 3.4 数据模型与序列化

本次逐项读了 lib/core/models 下 13 个模型及其 .g.dart、features 下 16 个模型，以及 api_data.dart 的 6
个 `normalize*` / `apiPageResult`、24 个服务文件的全部 fromJson 调用点、AuthProvider/关注标签/搜索历史的持久化解码与
MovieDetail/ActorDetail 的 copyWith/toJson。整体数据层相当扎实：所有模型的 fromJson 调用点都先经过
normalize 层（数字/字符串互转、缺字段兜底、嵌套数组过滤、分页 total_pages/满页推断），未发现手写解析与生成代码漂移；相等性只在
ActorFilter/ActorRange 上实现，其余无 `==` 的过滤模型在 UI 中逐字段比较，copyWith
也未见丢字段。剩余风险集中在启动/会话持久化的“严格解码”（可导致无法启动）和少量绕过统一解析层的路径，另有
MovieDetail.toJson 的往返陷阱。

**DATA-1｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/models/startup.g.dart:28
- 问题：启动响应中的 recent_keywords / recent_magnet_keywords 由生成代码逐项 `as String`
  ，settings/user 直接 `as Map<String,dynamic>?`，任一元素类型漂移都会让整个启动解析抛 TypeError。
- 影响：解析发生在 `StartupApiClient.fetchStartup`（lib/core/network/startup_api_client.dart:46）；
  `StartupProvider.load` 用 catch-all 把它转成启动失败（lib/core/providers/startup_provider.dart:
  81-86），启动页只提供“重试”。同一份响应每次都会抛同样异常，用户将无法进入
  App——非关键字段（热词）的漂移会拖垮整个启动链路，与项目在服务层做归一化的做法不一致。
- 证据：startup.g.dart:28-37
  `recentKeywords: (json['recent_keywords'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const []`，:
  38-39 `settings: json['settings'] as Map<String, dynamic>?`；startup_provider.dart:81-86
  `} catch (_) { _status = StartupStatus.failure; ... }`；startup_screen.dart:74-91 只渲染
  errorMessage + “重试”，:30-34 失败直接 return 不导航。
- 建议：为 StartupData 改为手写/`@JsonKey(fromJson:)` 容错解析（用
  apiList/apiString，跳过非字符串项），至少让热词/settings/user 解析失败降级为空而不是让启动失败。
- 复核说明：核心事实成立，仅失败页归属需修正：TypeError 不经过 main.dart:51-55（该 try/catch 只包
  `_buildEntry()`，而 `_buildEntry` 只 create StartupProvider，从未调用 load ()）；真正的加载在
  StartupScreen.initState 的 postFrameCallback（startup_screen.dart:25-27），失败 UI 是 StartupScreen
  的重试按钮，不是 StartupFailureScreen。另：“与其他字段统一用 apiString/apiInt 容错”略夸大——生成模型同样是严格
  `as String`，准确说法是启动数据绕过了归一化层；且 settings/user 在仓库内无任何消费点，即解析了但不用的字段同样能让启动整体失败。

**DATA-2｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/providers/auth_provider.dart:74
- 问题：读取旧版会话时直接 `_restoreSession(jsonDecode(encoded))`，create () 中 `:36` 与 `:48` 也直接
  jsonDecode + as Map 转换，没有 try/catch。
- 影响：只要 SharedPreferences 里残留的 `key_auth_session`/`key_user` 是损坏或旧格式值（jsonDecode 抛
  FormatException，或 `as Map` 抛 TypeError），`AuthProvider.create` 就会在 `_buildEntry`
  （lib/main.dart:68）中抛出；`_bootstrap` 把它变成 StartupFailureScreen，重试会再次读取同一个
  key，形成永久启动失败（除非用户清应用数据）。
- 证据：auth_provider.dart:36、:74、:48；对照 following_tags_store.dart:24-32、search_history_store.dart:
  19-27 都做了 try/catch，且 auth 的 secure read 本身也做了兜底（:29-34）。
- 建议：两条 decode 路径都包 try/catch，解析失败按未登录处理并清理坏 key。
- 复核说明：与 STATE-2 为同一缺陷（此处从数据层记录），复核结论见 STATE-2：核心事实成立；`_restoreSession`
  的模式匹配对“合法 JSON 但结构不符”是静默未登录，不会抛错；触发需依赖外部损坏/篡改或平台存储异常。

**DATA-3｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/rankings/services/ranking_service.dart:67
- 问题：`getActorRanking` 与 `_parseMoviePage` 用裸 `response.data as Map<String, dynamic>`，绕过了
  `apiMap` 的统一容错。
- 影响：排行接口若返回 `data: null`（成功但无数据）或形状变化，`getTop250`/`getPlayback`/`getRanking` 会抛
  TypeError；PaginationController 捕获后由 MovieGridView/PaginatedListView 直接把 `error.toString()`
  展示给用户（lib/core/widgets/movie_grid_view.dart:57-61），出现原始类型错误文案。其他 20 余个服务都使用
  `apiMap`（如 actor_service.dart:70、movie_detail_service.dart:28），甚至同一 `/rankings/actors` 端点的
  `ActorService.getRankingActors` 也用 apiMap。
- 证据：ranking_service.dart:67 `final data = response.data as Map<String, dynamic>;`；:84
  `final m = data as Map<String, dynamic>;`；对照 actor_service.dart:70
  `final data = apiMap(resp.data);`。
- 建议：改为 `final m = apiMap(response.data);`，非 Map 时返回空页而非抛异常。

**DATA-4｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/core/models/movie.g.dart:116
- 问题：生成的 `MovieDetail.toJson` 把 actors/actor_movies/relative_movies/top_rankings 原样写成模型对象，
  `MovieDetail.fromJson(detail.toJson())` 会在 `e as Map<String,dynamic>` 处抛 TypeError；同时
  tagItems/review 因 `includeToJson:false` 被静默丢弃。
- 影响：`MovieDetail.toJson()` 是公开 API，但既不能往返、也不完整。ActorDetail
  对这一陷阱有明确注释（actor.dart:97-98“不要用 fromJson (toJson ()) 复制实例”），MovieDetail 没有；测试也只断言
  toJson 不含 review（test/core/network/api_data_test.dart:251），没有覆盖往返。后续任何用 toJson
  做缓存/深拷贝的改动都会重蹈线上崩溃。
- 证据：movie.g.dart:116-121；movie.g.dart:54/64/69/82 的
  `?.map((e) => ...fromJson(e as Map<String, dynamic>))`；movie.dart:86/91
  `@JsonKey(includeToJson: false)`。
- 建议：让 toJson 递归输出 Map（或移除/降级为文档化的非往返 API），并像 ActorDetail 一样补注释说明不可
  `fromJson(toJson())`。

**DATA-5｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/profile/screens/profile_screen.dart:59
- 问题：`((auth.user ?? const {})['username'] as String? ?? '?')[0]` 对用户名字符串直接取首字符：username
  为空串时抛 RangeError，非字符串时 `as` 转换抛 TypeError。
- 影响：`AuthProvider.user` 是完全没有模型的 `Map<String,dynamic>`（auth_provider.dart:
  15,19），服务端只要对某账号返回 `username: ""`（或类型变化），进入“我的”Tab 就会在 build
  期抛异常，页面变成错误/红屏；同文件 :70/:75/:87/:93 也都是对同一 map 的直接断言/内插。
- 证据：profile_screen.dart:59；auth_provider.dart:15、:19。
- 建议：先取 `username?.trim()`，为空再回退到 `'?'`；更长远的做法是为 user 建一个容错模型/getter
  收敛这些动态访问。

### 3.5 架构与规范合规

逐文件核对了 lib/** 的 import/export 关系（含 17 个 feature 的 index.dart）、lib/router/ 的职责边界，并对照
RULES.md 与 STRUCTURE.md：index.dart 作为对外入口没有被绕过（lib 内 router、main 及各 feature 之间的引用都走
index.dart，core 也没有 import 任何 feature，feature 根目录无散落文件），分层基础是好的。但依赖方向存在两处系统性违背：feature
之间横向依赖（categories/profile → following），以及 core 与 feature 同时反向依赖
lib/router/routes.dart，后者还与规则文档自身的矛盾相互放大。死代码方面发现整个 settings feature（84 行）与
movie_preview_lease.dart（61 行）从入口完全不可达，另有三个 feature 的 index.dart 过度导出内部
service/model，core 内还存在 api_client ⇄ auth_interceptor 的 import 环。这些问题都不会导致现有 1005
个测试失败，但会直接影响后续边界维护与文档可信度；另有轻微文档漂移（STRUCTURE.md:74 未记录实际存在的
lib/features/auth/services/auth_session_service.dart）。

**ARCH-1｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/categories/screens/categories_screen.dart:11
- 问题：categories 与 profile 两个 feature 直接 import following feature 的入口，形成 feature 间横向依赖。
- 影响：违反 RULES.md:53“feature 只依赖 core，feature 之间不互相依赖”与 STRUCTURE.md:103“跨 feature
  复用必须上提到 core/”。触发条件是 following 的 widget 构造参数或 Screen 行为变更，此时必须同步修改
  categories 与 profile 两个无关 feature；第三个 feature 再复用时依赖会继续扩散，公共能力也无法沉淀到
  core。
- 证据：categories_screen.dart:11 `import 'package:jade/features/following/index.dart';`，在 :189 使用
  `FollowingTagsButton`（定义于 lib/features/following/widgets/following_tags_button.dart:5，其依赖的
  FollowingTagsProvider 本身已在
  core/providers/following_tags_provider.dart）；lib/features/profile/screens/profile_favorite_screens.dart:
  3 同样 import following/index.dart，:10
  `Widget build(BuildContext context) => const FollowingScreen();`。为支持这种跨 feature
  使用，lib/features/following/index.dart:3 还导出了私有 widget FollowingTagsButton。
- 建议：把 FollowingTagsButton 上提到 lib/core/widgets/；删除仅做透传的 ProfileFollowingScreen，在
  app_router.dart 中直接路由到 following 的 FollowingScreen。
- 复核说明：成立。用脚本遍历 lib/features 统计跨 feature import，全库仅 2 条横向边：categories→following
  与 profile→following；analysis_options.yaml 仅含 flutter_lints，无 feature 隔离 lint，test/
  无架构约束测试，规则目前纯靠文档约束。

**ARCH-2｜严重度：低｜复核状态：已复核（代码级）**

- 位置：lib/core/widgets/search_entry.dart:3
- 问题：core 与 feature 都反向 import lib/router/routes.dart，与文档声明的“feature → core
  单向”相冲突，且规则文档对路由位置自相矛盾。
- 影响：routes.dart 被放在组装层 lib/router/，而该目录下的 app_router.dart 依赖 16 个 feature 入口；因此
  core 和 feature 现在都依赖一个处于依赖链顶端的目录，任何路由文件位置/常量调整都要改动 core 与
  feature 两侧。更麻烦的是 RULES.md 把路由画在 `core/router/`，STRUCTURE.md:46 却明确要求放在
  `lib/router/` 而非 core，新成员无法判断哪条才是规范。
- 证据：core 侧 lib/core/widgets/search_entry.dart:3、list_summary_tile.dart:
  4、selectable_copy_search_text.dart:5 均为 `import 'package:jade/router/routes.dart'`；feature 侧共
  17 处，如 home_screen.dart:3、search_screen.dart:4、profile_screen.dart:4。约定出处：STRUCTURE.md:9、:
  46、RULES.md:53，以及 RULES.md:37 的树形图把 router/ 画在 lib/core/ 之下。
- 建议：把纯路径常量的 routes.dart 移到 lib/core/constants/app_routes.dart，lib/router/ 只保留
  GoRouter 组装；同时统一 RULES.md 与 STRUCTURE.md 的描述。
- 复核说明：问题实质成立，但两处细节需更正：a) `RULES.md:36` 应为 :37；b) “core
  依赖处于依赖链顶端的目录”在编译依赖粒度上不成立——routes.dart 全文 53 行仅含静态 const 与 2 个拼接方法、零
  import，core → routes.dart 并不构成 core → feature 的依赖倒置，真正依赖 16 个 feature 的是同目录的
  app_router.dart。故这是目录层级混用 + 文档自相矛盾，而非实际架构倒置。

**ARCH-3｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/settings/index.dart:1
- 问题：整个 settings feature（index.dart 1 行 + settings_screen.dart 53 行 + setting_item.dart 30 行，共
  84 行）从应用入口不可达，真实的设置页由 profile 的 ProfileSettingsScreen 承担。
- 影响：死代码与真实设置页并存：后续维护者若按目录语义把主题/线路/默认筛选等设置改进这个永远不上屏的页面，改动对用户完全无效（用户看到的是
  profile 的实现）；同时 STRUCTURE.md:75 仍把 settings 列为在用 feature，加深误导。
- 证据：`grep -rn "features/settings" lib/ test/` 只命中 settings_screen.dart:4 对 setting_item.dart
  的自引用，settings/index.dart 未被任何文件 import；lib/router/app_router.dart:335 的
  `/profile/settings` 使用的是 `ProfileSettingsScreen`（profile_settings_screen.dart:
  23），lib/router/routes.dart 也没有 settings feature 的挂载常量。从 main.dart 与 app.dart 做
  import/export 可达性遍历，lib/features/settings/ 三个文件均不可达。
- 建议：删除 lib/features/settings/ 并同步修正 STRUCTURE.md:75；若确实要独立成页，则在
  routes.dart/app_router.dart 注册它并移除 profile 内的重复实现。
- 复核说明：成立。routes.dart:51 确实存在 `profileSettings = '/profile/settings'`，只是不存在挂载
  settings feature 页面的常量，原证据措辞需微调。项目自有文档
  docs/comet/archive/2026-10-21-detail-online-play-sources/brief.md:38 已写明“不改
  lib/features/settings/（项目中的死代码目录，真设置页在 features/profile）”。

**ARCH-4｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/movie_detail/services/movie_preview_lease.dart:19
- 问题：`MoviePreviewLease` / `MoviePreviewLeaseCoordinator` 抽象从未被任何代码引用，是预告片设备状态重构后遗留的死文件。
- 影响：61 行无引用的抽象会误导后续开发者以为预告片的方向/常亮/系统栏仍走这套通用 lease 协议；实际实现已替换为
  MoviePreviewOperationManager。修改该文件不会产生任何行为变化，属于纯维护成本与误改风险。
- 证据：`grep -rn "MoviePreviewLease\|movie_preview_lease" lib/ test/` 仅命中该文件自身；实际使用方
  movie_preview_screen.dart:6 导入的是 movie_preview_operation_manager.dart，后者自带
  `MoviePreviewOperationLease` 与 acquire/acquireWakelock/release 生命周期（:44-70）。可达性遍历中该文件从
  main.dart/app.dart 不可达。
- 建议：删除 movie_preview_lease.dart；若仍需要通用 lease，则在 MoviePreviewOperationManager 中复用并补测试。

**ARCH-5｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/core/network/api_client.dart:13
- 问题：`TokenProvider` 定义在 api_client.dart，导致 api_client ⇄ auth_interceptor 形成双向 import 环。
- 影响：网络层两个文件的初始化与扩展顺序被耦合；想单独复用 AuthInterceptor 必须连带引入整个
  ApiClient（含 Dio、SharedPreferences 实现细节），未来把网络层抽包或单独测试拦截器时无法只依赖抽象。
- 证据：api_client.dart:5 import auth_interceptor.dart；auth_interceptor.dart:2 import api_client.dart
  仅为使用 api_client.dart:13 的 `abstract class TokenProvider`。对 lib/** 全部 import/export 做
  Tarjan SCC 检测，唯一文件级环即这两个文件。
- 建议：把 TokenProvider 抽到独立文件（如 core/network/token_provider.dart），让拦截器只依赖抽象。

**ARCH-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/home/index.dart:5
- 问题：三个 feature 的 index.dart 导出了没有任何模块（含路由）使用、仅 feature 内部使用的
  service/model。
- 影响：违反 RULES.md:54 与 STRUCTURE.md:102“对外只 export 路由需要的 Page 与公开模型，内部实现细节不暴露”。这些导出扩大了公开
  API 面：重构 HomeService/RecentViewedService/Article 时会被误认为存在外部契约，feature 入口也无法反映真实边界。
- 证据：home/index.dart:5-6 导出 home_service.dart 与 home_provider.dart，但二者只在 feature
  内被使用；profile/index.dart:8 导出 recent_viewed_service.dart，在 lib/features/profile/
  之外无命中；articles/index.dart:1 导出 models/article.dart，在 lib/features/articles/ 之外无命中。
- 建议：删除这三条 index 导出，仅保留 Screen 导出。

### 3.6 测试质量与覆盖

按要求只读审查了 test/** 全部 157 个测试文件并对照 lib/ 实现与任务给出的覆盖率基线（未重复运行
flutter test/analyze）：整体质量较高——没有 skip/todo，也没有跨用例共享可变状态或执行顺序依赖（各测试文件独立
isolate，ApiClient/SharedPreferences 均在 setUp
中重建），未发现过度断言私有实现，核心网络、搜索分页、影评详情的用例大多验证请求参数与状态迁移。主要问题集中在“覆盖率盲区 +
名不副实的断言”：注册提交链路、演员筛选/信息面板、启动失败兜底、存入清单失败回滚等用户关键分支没有测试，CachedImage
的三条名为 URL/尺寸的测试实际只断言 widget 存在。这些缺口一旦发生回归，现有 1005
个用例仍会全绿，属于覆盖率数字之外的假安全；未发现可报告的计时器泄漏（基线全部通过，flutter_test
结束时会报告未取消的 Timer，本维度未重新执行测试）。

**TEST-1｜严重度：中｜复核状态：已复核（代码级）**

- 位置：test/features/auth/register_screen_test.dart:29
- 问题：注册页测试只渲染并回显输入，提交/校验/错误/跳转零覆盖；名为“注册”的 API 用例也没有调用真正的
  `AuthSessionService.register`。
- 影响：register_screen.dart 行覆盖率仅 41%，`_register()`（register_screen.dart:
  42-84）在测试中从未执行：两次密码不一致、密码少于 6 位、ApiException 提示、loading 期间禁用按钮、from
  参数跳转这些用户直接可见的分支没有任何回归保护。且当前测试环境不创建 ApiClient，
  `AuthSessionService.resolve()` 返回 null（auth_session_service.dart:12-19），即便补一次点击也会在
  register_screen.dart:43-44 直接 return，任何断言都不会触达业务分支。
- 证据：register_screen_test.dart:29-51 仅 `enterText` 后
  `expect(find.text('test@test.com'), findsOneWidget)`；在 test/ 下 grep `register(` 无命中，唯一相关的是
  api_integration_test.dart:740-759“POST /api/v1/users → 注册（含设备信息）”，它手写整个请求体后只
  `expect(adapter.requests.last.path, Endpoints.users)`，从未调用 `AuthSessionService.register`
  ，服务端字段契约写错测试也不会红。
- 建议：给 RegisterScreen 注入 AuthSessionService（构造参数或工厂回调），补“密码不一致 / 密码过短 /
  接口报错 / 成功跳转（含 from）”四个 widget 用例，并让注册 API 测试直接调用 `service.register`
  校验实际提交的字段。
- 复核说明：核心事实坐实。原引用 `:36-55` 指向 main () 开头属行号笔误，注册用例正确位置是 :
  740-759；“行覆盖率 41%”未在复核中实测（无 coverage 产物、未运行测试），仅作辅助。

**TEST-2｜严重度：中｜复核状态：已复核（代码级）**

- 位置：test/features/actors/actor_detail_screen_test.dart:74
- 问题：演员详情的筛选/排序与信息面板没有任何测试：ActorMovieFilterSheet、ActorInfoSheet 行覆盖率为
  0%，ActorMovieController 仅 49%，而详情页测试只覆盖收藏按钮。
- 影响：详情页“筛选”与“更多信息”入口（actor_detail_screen.dart:159-163、193）在所有测试中从未被点击；
  `ActorMovieController.toggleTag/changeSort/toggleOrder` 生成的 `filter_by_tags`/`sort_by`/
  `order_by` 参数（actor_movie_controller.dart:
  75-111）以及标签面板的数量渲染若回归，页面仍能正常渲染、测试全绿，用户会得到筛选无效的影片列表，或因类型/参数错误导致面板崩溃。
- 证据：actor_detail_screen_test.dart:74-164 只有 4 个收藏用例，且 `enqueueEmptyMovies`（:
  51-60）让影片列表恒为空；在 test/ 下 grep `ActorMovieFilterSheet|showActorInfoSheet`
  无任何命中（test/features/actors/actor_filter_sheet_test.dart 测的是列表页
  ActorFilterSheet，不是本面板）；基线覆盖率：actor_movie_filter_sheet.dart 0%（58
  行）、actor_info_sheet.dart 0%（75 行）、actor_movie_controller.dart 49%。
- 建议：为 ActorMovieController 增加纯单元测试（多选标签的逗号拼接、排序/升降序参数、preserveItems
  重载、dispose 后调用），并补两个 widget 测试：点“筛选”勾选标签断言请求参数，点“更多信息”断言占位符 `--`
  与 `N 岁` 后缀。
- 复核说明：核心事实全部核实；两个面板 0% 可由“无测试引用”确定性推得，具体百分比与行数未在复核中重跑
  coverage。补充：`_showFilter` 在 `_controller == null` 时静默返回（actor_detail_screen.dart:
  115-117），而筛选按钮无条件渲染（:159-163），未测分支确实存在。

**TEST-3｜严重度：中｜复核状态：已复核（代码级）**

- 位置：test/core/widgets/cached_image_test.dart:31
- 问题：三个以“CDN 拼接 / width-height”命名的测试只断言 CachedImage 自身存在，把 `_fullUrl`
  或尺寸透传删掉它们依然通过。
- 影响：CachedImage 是所有封面/剧照的入口，`_fullUrl`（cached_image.dart:46-52）决定相对路径是否拼
  `domainManager.imageEndpoint` 或 `AppConstants.fallbackImageCdn`；测试从未读取
  `CachedNetworkImage.imageUrl`，仓库内唯一相关断言 movie_card_test.dart:91 只检查
  `endsWith('thumbs/thumb.jpg')`，不校验前缀来源。一旦拼接逻辑回归（如域名切换后图片基地址错误、http URL
  被二次拼接），全站图片会 404/变形，而这三条用例仍然全绿。
- 证据：cached_image_test.dart:31-55 三条用例均为
  `pumpWidget(MaterialApp(home: CachedImage('covers/test.jpg'))); expect(find.byType(CachedImage), findsOneWidget);`
  ，没有任何 imageUrl、width、height 断言；对应实现 cached_image.dart:44-51 的分支完全未被验证。
- 建议：改为断言 `tester.widget<CachedNetworkImage>(...).imageUrl` 等于 `fallbackImageCdn + path`
  、http 开头原样返回，并断言 width/height 透传；再创建带自定义 imageEndpoint 的 ApiClient 验证域名前缀。
- 复核说明：成立（`_fullUrl` 实际为 46-52 行、CachedNetworkImage 构造在 :
  60，属轻微行号偏差，不影响结论）。这是测试有效性/回归防护缺口而非现存用户可见错误。

**TEST-4｜严重度：低｜复核状态：已复核（代码级）**

- 位置：lib/main.dart:49
- 问题：启动失败兜底链路（`_bootstrap` catch → StartupFailureScreen → 重试重新初始化）没有任何测试，
  `mainForTest` 完全绕开了 `_bootstrap`。
- 影响：main.dart 覆盖率为 64%，未覆盖的正是避免永久白屏的 catch（main.dart:53-56）。若初始化抛错后
  runApp 未执行、重试回调未重跑 `_buildEntry`、或错误页未挂载，用户会停在白屏；现有
  startup_failure_screen_test 只测孤立 widget 的文案与回调计数，无法覆盖“初始化失败 → 错误页 →
  点重试 → 进入首页”的闭环。
- 证据：main.dart:27-39 的 `mainForTest` 直接 `runApp(await _buildEntry(...))`，不经过 `_bootstrap`
  ；test/app_test.dart:29、41 只调用 `mainForTest`；在 test/ 下 grep `_bootstrap`
  无命中；startup_failure_screen_test.dart 仅构造 widget 并断言 retries 自增。
- 建议：抽出一个可注入依赖的 `bootstrap(runApp)` 函数并补测试：依赖抛错时断言渲染
  StartupFailureScreen，依赖恢复后点“重试”断言进入首页。
- 复核说明：核心事实成立，但属测试缺口——当前 `_bootstrap` 的 catch 已正确闭环（错误页挂载、onRetry 指向
  `_bootstrap`、重试重跑 `_buildEntry`），“用户会停在白屏”是回归风险而非现状。覆盖率 64% 未在复核中实测。

**TEST-5｜严重度：低｜复核状态：已复核（代码级）**

- 位置：lib/features/movie_detail/widgets/save_to_list_sheet.dart:142
- 问题：“存入清单”弹窗的失败分支与乐观更新回滚完全无测试：加载更多失败、添加/移除失败回滚、创建清单失败均未覆盖。
- 影响：`_toggleList` 先本地勾选并按 ±1 修改计数（:126-131），失败后才回滚（:142-143）；回滚写错（index
  失效、失败后仍保留 pending 状态）会让用户看到“已加入”而服务器未加入，或计数长期错误，属于用户可见的错误状态，而三个失败提示没有任何测试命中。
- 证据：在 test/ 下 grep `清单加载失败|添加失败|移除失败|创建清单失败`
  只命中无关的“相关清单加载失败”（movie_detail_screen_test.dart:2578）；现有用例覆盖打开与 401（:
  2265-2380）、toggle 成功字段与创建成功（:2420-2480），不覆盖 save_to_list_sheet.dart:112-115、:138-144、:
  160-166 的 catch/回滚路径；基线覆盖率 73%。
- 建议：补四个用例：loadMore 失败提示且保留旧列表、add/remove 失败后复选框与计数回滚、创建失败提示且输入保留、创建成功刷新列表。
- 复核说明：核心事实成立。需修正：a) “copyWith 丢字段”在当前代码不成立（list_model.dart:24-33
  保留全部字段，回滚恢复的是原始 list 对象）；b) 原发现未点出的真实隐患——:142 使用 :120 捕获的 index，而
  `_loadFirstPage`（:57-85，由创建成功后 :162 及重试 :237 调用）会在 toggle 在途时整体替换 `_lists`
  ，索引可能错位导致回滚覆盖错误条目，同样无测试。

**TEST-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：test/features/profile/collected_entities_page_test.dart:85
- 问题：收藏的实体页只覆盖“片商”一种分类，系列/导演/番号三类分支以及分页未测；收藏清单页只覆盖排序切换，取消收藏路径未测。
- 影响：CollectedEntitiesScreen 的 `_fetchPage/_idOf/_nameOf/_countOf/_uncollectById` 都按 category 做
  4 路 switch 和强转（collected_entities_screen.dart:45-66、78-108），测试只走 'm'（:94、:132）。若
  's'/'d'/'c' 任一分支被接错数据源或强转错模型（典型复制粘贴回归），列表渲染会直接抛类型错误；'c'
  的标题特例（:142 `取消收藏${...=='c' ? '番号' : ...}`
  ）也无断言。清单页测试只切换排序（collected_lists_page_test.dart:74-94），`uncollectList` 是空实现（:
  35），取消收藏成功/失败与分页均未覆盖。基线 collected_entities_screen 64%、collected_lists_screen 65%。
- 证据：collected_entities_page_test.dart:85、122 两个用例的 category 均为 'm'（:94、:132），fake 的
  `getCollectedMakers` 忽略 page 且固定 `totalPages: 1`（:
  23-30），滚动分页不会被触发；collected_lists_page_test.dart:35 的
  `Future<void> uncollectList(String id) async {}` 无任何断言。
- 建议：参数化补 's'/'d'/'c' 三类用例（断言名称/计数与跳转 query 的
  category、title），并补清单取消收藏成功/失败与第二页加载用例，fake 按 page 返回不同数据。

### 3.7 性能与资源生命周期

整体上资源生命周期做得比较扎实：通读了预告片播放页及其 lease 协调器（方向/常亮/系统栏/亮度）、图片管线、分页与列表组件、以及主要
screens 的 State；Timer、TextEditingController、ScrollController、PageController、TabController 与
ImageStreamListener 都有对应的释放路径，播放器的 StreamSubscription/Player 在 dispose 中按序取消，列表统一使用
builder+自动分页、Tab 保活与懒加载，轮播也按 TickerMode/AppLifecycle
停播。主要问题集中在图片管线（剧照为测宽高比引入不受尺寸限制的解码、解密服务逐字节装箱并多次整图复制）与通知粒度（分页
tick 被 CategoryTabController 原样转发，导致整页/整个筛选面板反复重建），另有筛选即时请求、items 全量拷贝和两处
ChangeNotifier 未 dispose 的小问题。本维度只做静态阅读（仅执行过一次 `flutter --version` 用于定位 SDK
源码），未运行 analyze/test/format/coverage，基线数据取自任务说明。

**PERF-1｜严重度：低｜复核状态：已复核（代码级）**

- 位置：lib/core/network/image_decryptor.dart:45
- 问题：图片解密服务把响应流按字节展开成 `List<int>` 后整体缓冲，并在解密时再做一至两次等长
  `Uint8List` 复制，全部发生在 UI isolate。
- 影响：所有带常见图片扩展名的 URL（`looksLikeEncryptedImageUrl` 对 .jpg/.png 等恒为 true）缓存未命中时都要先付出约
  8 倍字节数的中间列表（64 位下每个元素槽位约 8 字节）再加 1–2 次整图拷贝；1MB 的资讯大图会产生约 10MB
  瞬时分配，多图并发加载时造成 GC 抖动与滚动掉帧，且这些工作无法被 generation 丢弃。
- 证据：image_decryptor.dart:40-48 `get` 执行
  `await response.content.expand((chunk) => chunk).toList()`（:45）；`decryptMobileImageBytes`（:
  19-27）再用 `Uint8List.fromList(data)` 复制、加密图再
  `Uint8List.fromList(Uint8List.sublistView(...))` 复制一次；:5-10 的后缀判定覆盖全部常见图片；JdbImageCacheManager
  把它设成所有 CachedImage 的 fileService（:51-63，cached_image.dart:60-62）。全仓库 grep 无
  CancelToken。
- 建议：改用 BytesBuilder/Uint8List 收集分块（或边读边 XOR），只按首字节判断是否需要解密，避免逐字节装箱列表与多次整图复制；大图可放到
  compute/isolate。
- 复核说明：行为与推理成立；但按锁定的 flutter_cache_manager 3.4.1，`_pushFileToStream` 仅在无缓存或过期时才进入
  `fileService.get`，且 stalePeriod 为 7 天，因此 8 倍缓冲与拷贝只发生在每张图首次下载/过期重下时一次，命中央盘缓存时不触发。8MB/10MB
  与“GC 抖动、掉帧”为量级推算，未实测。

**PERF-2｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/widgets/movie_still_thumbnail.dart:71
- 问题：剧照缩略图借 ImageSizeListener 持有的“无解码尺寸限制”provider 测量宽高比，使每张剧照按原图分辨率解码并常驻
  ImageCache（与 PLAY-3 同一问题）。
- 影响：详情页横条槽位只有 164dp 高（DPR3 约 492px），1080p 剧照会解码成约 8MB/张；ImageSizeListener 在整个
  widget 挂载期持有该 ImageStream，解码图处于 live 状态不会被 100MiB 默认 ImageCache 回收，几张剧照即可占数十
  MB，挤压封面缓存并放大回滑时的重解码/GC。
- 证据：movie_still_thumbnail.dart:71 `CachedImage(widget.url, onImageSize: _handleImageSize)` 未传
  memCache；cached_image.dart:109-118 只要传 onImageSize 就另建无 maxWidth/maxHeight 的
  `CachedNetworkImageProvider(_fullUrl, cacheManager: ...)` 交给
  ImageSizeListener，image_size_listener.dart:42-51 resolve 并长期 addListener。槽位见
  basic_info_sections.dart:141（height: 164）。项目自身约定见 cached_image.dart:
  42-44“小槽位应传入以避免解码整张原图”，同类 84×56 剧照在 movie_list_tile.dart:87-91 已限制为
  170×114。Flutter 3.44.8 的 image_cache.dart:19 默认上限为 `100 << 20`。
- 建议：让宽高比测量复用同一个带 memCache 的展示 provider（ResizeImage 等比缩放不改变宽高比），已记忆
  aspect 时不再传 onImageSize，并给剧照传 memCacheHeight ≈ 164×DPR。
- 复核说明：代码事实成立；“再次进入必然重复全尺寸解码”表述偏强——若该 key 仍在 ImageCache
  中则为缓存命中而非重新解码。

**PERF-3｜严重度：低｜复核状态：已复核（代码级）**

- 位置：lib/features/categories/screens/categories_screen.dart:73
- 问题：CategoryTabController 把 PaginationController 的每次通知原样转发，而 CategoriesScreen 只为刷新
  AppBar 关注按钮就监听它并无参 `setState` 重建整页。
- 影响：每个分页请求（开始/结束各一次 notify）都会额外触发约 2 次整页重建：AppBar + TabBarView + 已挂载
  Tab 的网格；重建时还会重新分配 `controller.groupOrder`（全量分组/tagId 列表）并遍历分组计算
  `hasSelectedTags`，标签多的分类会随翻页持续产生无谓分配和主线程工作量。同一根因还让打开中的筛选面板随分页
  tick 整体重建。
- 证据：category_tab_controller.dart:19-20 构造时 `movies.addListener(_notifyFromMovies)`，:142
  `_notifyFromMovies() => _notify()` 不区分来源；pagination_controller.dart:37、:54 每次 `fetchMore`
  前后各 notify；categories_screen.dart:57-65 仅为选中 Tab 注册监听且切换后不移除，:73-75 在 postFrame
  中 `setState(() {})`；重建路径 categories_screen.dart:176-222，AppBar 内 :185-191 调用
  `controller.groupOrder`（:41-48 每次新建列表）与 `hasSelectedTags`
  。同类模式：actor_movie_filter_sheet.dart:24-26 的 ListenableBuilder 在筛选期间每次分页 tick 重建全部
  FilterChip。
- 建议：拆分分页通知与筛选通知（页面只监听 filter 变化），关注按钮用 ListenableBuilder/Selector 局部重建，并缓存
  groupOrder 在筛选变更时失效。
- 复核说明：核心链路全部证实；不精确处：actor_movie_controller.dart 的 addListener 实际在 :25（:30 是
  `final String actorId;`），“5 个 Tab 网格”是上界（仅已构建/keepAlive 的页会重建）；roll 事件不会逐帧触发，
  `_isLoading/_hasMore` 守卫会提前返回。无崩溃或可见错误，定 low。

**PERF-4｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/categories/services/category_tab_controller.dart:112
- 问题：筛选面板每个 chip 点击都立即触发一次 page 1 重新请求，既不合并也不取消在途请求。
- 影响：“多选、即时生效”下连续点选 N 个标签就会发出 N 个 page 1 请求（每个 48 条），只有最后一个结果被采用（generation
  丢弃旧的），前面的下载/JSON 解析/模型构造全部浪费；弱网时后发请求还会被在途请求拖慢，最终列表出现前有明显可感知延迟。
- 证据：category_filter_sheet.dart:117-124 每个 FilterChip 的 `onSelected` 直接
  `controller.toggleFilter(...)` → category_tab_controller.dart:112-117 立即
  `movies.reloadWith(_fetchPage, preserveItems: true)` → pagination_controller.dart:59-75 中
  reloadWith 立即调用 fetchMore，而 fetchMore（:29-57）只重置 `_isLoading` 并用 generation 丢弃旧结果；全仓库无
  CancelToken。同一模式见 actor_movie_filter_sheet.dart:130-139 + actor_movie_controller.dart:75-84。
- 建议：筛选变更做 200–300ms 防抖/合并后再 reload，并在 reload 时用 Dio CancelToken 取消上一个在途请求。

**PERF-5｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/core/widgets/pagination_controller.dart:20
- 问题：`items` getter 每次访问都通过 `List.unmodifiable` 复制整份已加载列表，而列表/网格的
  itemBuilder 里还按索引反复访问它。
- 影响：已加载条目越多复制成本越高；滚动时每个可见 item 都会触发 1–5 次全量复制与新建 List
  分配（ActorGridView 同一个 item 最多访问 items 5 次），属于随分页增长的、完全可避免的 CPU 与 GC 压力。
- 证据：pagination_controller.dart:20 `List<T> get items => List.unmodifiable(_items);`
  ；movie_grid_view.dart:95-97（itemCount 与 itemBuilder 各访问一次）、actor_grid_view.dart:
  112、118-134（length/actor/onTap/selected 最多 5 次）、paginated_list_view.dart:44、47-48。
- 建议：返回 `UnmodifiableListView(_items)`（零拷贝视图）或提供 length/itemAt，build 开头取一次局部变量。

**PERF-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/movie_detail/screens/movie_detail_screen.dart:355
- 问题：页面自持有的 ChangeNotifier 未在 dispose 中释放：MovieDetailScreen 的 ReviewStatusState 与
  HomeScreen 的 HomeProvider。
- 影响：每次关闭影片详情页都会留下一个未 dispose 的 ChangeNotifier（Flutter leak tracking
  会标记泄漏），若日后有异步回调在页面销毁后触达它会直接触发“used after dispose”；HomeProvider
  在页面重建时同样会遗留。属资源生命周期约定缺失，当前无可见功能后果。
- 证据：movie_detail_screen.dart:35 `final ReviewStatusState _reviewStatus = ReviewStatusState();`
  ，而 :354-360 的 dispose 只释放 `_magnetsState/_reviewsState/_relatedListsState`，全文无
  `_reviewStatus.dispose()`；home_screen.dart:21、34 在 `_load()` 中创建 HomeProvider，
  `_HomeScreenState`（:20-268）没有 dispose 覆写。对照 detail_section_state.dart:62-66 等同类状态均实现了
  dispose。
- 建议：MovieDetailScreen.dispose 增加 `_reviewStatus.dispose()`；HomeScreen 增加 dispose 释放
  `_provider`（或改由 ChangeNotifierProvider 管理）。

### 3.8 错误处理与健壮性

整体看，网络层与页面骨架的健壮性投入较多：统一拦截器与超时、鉴权失效跳登录、PaginationController 用
generation 丢弃过期响应、详情页分区状态与 BusyPageState 写操作互斥，这些方面未发现明显缺陷。主要问题集中在错误类型未映射到用户文案：登录/注册对
ApiException 的 catch 实际上不可达，页面错误态普遍直接展示 DioException
原文。会话/线路层面的容错也有缺口：本地会话反序列化失败会让 App 永久停在启动失败页，DomainSwitchInterceptor
的全局 `_retried` 让自动换线在进程内只能生效一次；演员详情失败后无重试入口，点赞失败被误报为“已点过赞”。重复提交方面评论/收藏/清单创建均有
busy 守卫，仅登录/注册的键盘提交缺少入口 loading 守卫（login_screen.dart:69、register_screen.dart:
42），存在重复请求可能但影响有限。

**ERR-1｜严重度：高｜复核状态：已复核（代码级）**

- 位置：lib/features/auth/screens/login_screen.dart:115
- 问题：登录/注册页的 `on ApiException` 分支永远命中不到：拦截器把 ApiException 包在
  `DioException.error` 里 reject，页面最终走 `catch (e)` 并把 DioException 的原始 `toString` 显示给用户。
- 影响：任何登录/注册失败（密码错误、参数无效、服务端 5xx）都会显示形如“DioException [bad response]:
  null / Error: ApiException (...)”的英文技术文本，而不是服务端的中文 message；用户无法区分是密码错误还是网络故障。另外
  payload 缺少 token/user 时（`data['token'] as String`）会抛
  TypeError，同样走原始异常文案。测试只断言了未登录状态，没有断言错误文案，所以全量测试通过也覆盖不到。
- 证据：response_interceptor.dart:39-47
  `handler.reject(DioException(... error: ApiException.fromAction(...)))`——ApiException 只作为
  DioException.error 存在；Dio 5.10.0 的 `assureDioException` 不会解包。login_screen.dart:115-126
  `on ApiException catch (e) { ... } catch (e) { _error = e.toString(); }`；register_screen.dart:
  71-82 同样结构；login_screen.dart:88-89 对 token/user 直接强转。对比同仓库
  token_authentication_dialog.dart:46-58 正确地从 `error.error` 解包 ApiException，说明登录/注册漏掉了这一步。
- 建议：在服务层或统一错误映射处把 DioException 解包为 ApiException（或提供
  `userFacingMessage(Object error)`），登录/注册改为捕获 DioException 并读取 `error.error`；对
  token/user 缺失做显式校验，补一条断言错误文案的用例。
- 复核说明：成立。服务端中文 message 并未完全丢失，它被拼在 DioException 文本的 `Error: ...`
  之后，只是被英文技术串包裹；response_interceptor_test.dart:14-22 的 `_TestHandler` 用
  `throw error.error!` 手动抛出 ApiException，掩盖了真实 Dio 行为，api_client_test.dart:184 反而明确断言逃逸物是
  DioException 且 `error.error is ApiException`。

**ERR-2｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/providers/auth_provider.dart:36
- 问题：会话恢复对本地持久化字符串直接 `jsonDecode`/`as Map`，没有任何解析容错；损坏或非预期格式的会话值会让
  `AuthProvider.create` 抛异常，而该异常发生在启动页的重试无法修复的位置。
- 影响：本地 secure storage / SharedPreferences 中的会话内容一旦损坏或格式不符（旧版本残留、异常写入），
  `_bootstrap` 会进入 StartupFailureScreen，且重试按钮只是重跑 `_buildEntry`，坏数据从未被清除，App
  每次启动都失败，用户只能清除应用数据。代码注释明确写了“个别设备上 secure storage
  平台层可能抛错；兜底为未登录继续启动”，但只兜住了 read 失败，没兜住 decode/类型转换失败。
- 证据：auth_provider.dart:29-38（read 在 try/catch 内，36 行 decode 在 try 外）、:46-48、:
  70-75；main.dart:49-57 `runApp(StartupFailureScreen(error: error, onRetry: _bootstrap))`
  ；startup_failure_screen.dart:24-26 重试仍走同一路径，且没有清理坏键的逻辑。
- 建议：对每个存储值做 try/catch 解析：失败时记录日志、删除该键并降级为未登录（或仅忽略该来源），确保启动不被本地数据阻断；补充畸形
  JSON/非 Map 的回归测试。
- 复核说明：与 STATE-2/DATA-2/USER-3 为同一缺陷。核心事实一致：只有“无法解析的 JSON”会在 secure
  路径抛错，“合法 JSON 但结构不符”会被模式匹配静默忽略；`as Map` 的类型错误只出现在 :48 的旧 prefs
  路径。正常写入均经 jsonEncode，触发需依赖存储损坏、备份还原或旧版本残留。

**ERR-3｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/network/interceptors/domain_switch_interceptor.dart:32
- 问题：`_retried` 是拦截器实例级字段，成功后也从不复位（全仓库仅第 12/32/42
  三处引用），导致自动线路轮转在整个进程生命周期内只能触发一次。
- 影响：第一次自动换线成功后，如果新线路之后再被封/连接失败（608/connectionError），拦截器会因
  `_retried == true` 直接放行错误，不再调用 `DomainManager.rotate`
  ，所有后续请求持续失败并展示错误页。这与设置页“请求失败时自动切换可用线路”的承诺（profile_pickers.dart:
  41）以及 DomainManager 支持循环轮转的设计（domain_manager.dart:106-114 取模轮转）相矛盾；用户需要杀进程重启才能恢复自动换线。
- 证据：domain_switch_interceptor.dart:12、:32、:42，之后没有任何复位逻辑；api_client.dart:40-46 在 App
  启动时只注册一个该拦截器实例；测试 domain_switch_interceptor_test.dart 只验证单次轮转，没有第二次轮转用例。
- 建议：把“是否已重试”放到单次请求作用域（如 `RequestOptions.extra` 标记）而不是拦截器实例字段，或至少在
  `onResponse`/轮转成功时复位；补一条连续两次轮转的测试。
- 复核说明：与 SEC-2 为同一缺陷（此处从错误处理层记录）。SEC-2 定为高、本条定为中，合并排序时按高优先处理；
  `_retried` 置于 `dio.fetch` 之前是防止重试请求再次进入 onError 造成无限递归所必需，问题在作用域而非位置。

**ERR-4｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/widgets/movie_grid_view.dart:59
- 问题：多个列表/详情页把捕获到的异常对象 `error.toString()` 直接作为错误面板文案传给
  ErrorRetryWidget，用户看到的是 DioException 的英文技术描述而不是中文提示。
- 影响：断网、超时、服务端 5xx 或解析失败时，页面错误态会显示“DioException [connection error]:
  ...”“DioException [bad response]: ...”等英文文本，用户无法理解发生了什么；项目其余文案均为中文硬编码，这是明显的用户可见错误文案不一致。
- 证据：movie_grid_view.dart:57-61
  `ErrorRetryWidget(message: widget.controller.error.toString(), ...)`；同一写法还出现在
  paginated_list_view.dart:22-26、actor_grid_view.dart:59-63、movie_detail_screen.dart:90-96 与 :
  367-370、article_detail_screen.dart:118-121、actors_screen.dart:
  153-157、history_recommend_detail_screen.dart:63-65、top250_tab.dart:103-107、reviews_screen.dart:
  109-113。ErrorRetryWidget 本身提供了中文默认文案“加载失败”（error_retry_widget.dart:6）。
- 建议：在 core 层提供统一的 `userFacingErrorMessage(Object error)`（ApiException.message
  优先；连接/超时→“网络连接失败，请检查网络”；其他→“加载失败，请重试”），所有 ErrorRetryWidget
  调用点改用它，原始异常只写日志。
- 复核说明：成立。补充：home_provider.dart:26 `HomeSection(..., error: error.toString())` 经
  home_screen.dart:165-167、:190-192 展示，属跨页面系统性写法；即使服务端返回中文
  message，展示内容仍是“DioException [bad response]: ... Error: ApiException (...):
  中文”，夹带英文技术前缀。现有测试只断言 ErrorRetryWidget 存在与可点击，不断言文案。

**ERR-5｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/actors/screens/actor_detail_screen.dart:141
- 问题：演员详情页加载失败时只渲染一行 `Text(_error!)`（原始异常字符串），没有重试按钮或中文错误文案；
  `_load` 也没有在开头重置 `_error`/`_isLoading`，因此没有任何恢复入口。
- 影响：任何网络或解析错误都会让用户停在只有英文异常文本的页面，只能返回上一页重新进入；对比影片详情页同一场景使用
  ErrorRetryWidget 可原地重试（movie_detail_screen.dart:367-370），两页错误体验不一致。`_load` 仅在
  initState 调用，页面内不存在再次加载的路径。
- 证据：actor_detail_screen.dart:100-106 `_error = e.toString(); _isLoading = false;`；:141-146
  `if (_error != null) { return Scaffold(appBar: ..., body: Center(child: Text(_error!))); }`，没有
  onRetry/ErrorRetryWidget；:64-69 initState 只调用一次 `_load()`。
- 建议：错误态改用 ErrorRetryWidget + 固定中文文案，并在 `_load` 开始时重置 `_error` 与 `_isLoading`，把
  `_load` 作为重试回调。
- 复核说明：成立。catch 块还包住了 :98 的 `controller.initialize()`，影片列表初始化失败也会把整页打成错误态；
  `_load` 全文只在 initState 被调用，无页面内再次加载路径。

**ERR-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/core/widgets/review_tile.dart:80
- 问题：点赞请求失败时用 `catch (_)` 把所有异常（离线、超时、5xx、鉴权/解析错误）统一提示为“你已经点过赞了”，把失败误报成已点赞。
- 影响：用户断网点赞会收到“你已经点过赞了”，但本地 `_liked` 仍为 false（未更新），UI
  与提示矛盾；用户不会得知是网络失败，也没有明确的失败/重试语义。错误类型在 `DioException.type` /
  `ApiException` 中是可区分的，却被一律吞掉。
- 证据：review_tile.dart:69-85 中
  `try { await ReviewApi(api).likeReview(...); ... _liked = true; ... } catch (_) { if (!mounted) return; _showSnackBar('你已经点过赞了'); }`
  ；只有成功分支更新 `_liked`，catch 分支没有区分任何错误类型。
- 建议：仅当服务端明确返回“已点赞”语义时提示已赞，其他异常统一提示“点赞失败，请重试”；可按
  ApiException/DioException.type 区分并保留可重试状态。

### 3.9 UI 一致性与可访问性

按主题 token 与暗色适配、点击区域、Semantics、文本缩放与溢出、对比度、动效、空态与加载七个方面，静态审查了
lib/core/theme/app_theme.dart、lib/core/widgets 的公共组件，以及
auth/home/movie_detail/profile/rankings/actors/articles/categories/following/search 等 feature 的
screens/widgets。主题骨架健康：光/暗均来自 `ColorScheme.fromSeed` + `ThemeMode.system`
，EmptyState/ErrorRetryWidget/PaginatedListView/BusyPageState 等状态组件复用良好，MovieDetailTitleBar
与 StarRating 已专门处理大字号和语义；问题集中在少数自绘组件、表单布局与滑动交互上，共 6
条可定位的具体缺陷。按要求未运行工具链，结论来自代码阅读、rg 检索以及对 Flutter SDK 与 flutter_slidable
源码的核对。

**UIUX-1｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/profile/screens/collected_lists_screen.dart:117
- 问题：取消收藏/删除/改名/取消关注等破坏性操作只存在于 Slidable 的隐藏 action pane，没有点击或读屏可用的替代入口。
- 影响：只能通过横向拖拽触发（路径手势，WCAG 2.5.1），且 flutter_slidable 不产出任何
  Semantics，隐藏动作不在语义树中（WCAG 4.1.2）：读屏用户和无法完成拖拽的操作障碍用户无法取消收藏清单/演员/番号、编辑或删除清单、取消关注标签。
- 证据：collected_lists_screen.dart:117-131 仅
  `Slidable(endActionPane: ActionPane(children: [SlidableAction(label: '取消收藏')]), child: ListSummaryTile(...))`
  ；同类：collected_entities_screen.dart:180-196、my_lists_screen.dart:
  118-141（编辑/删除）、following_screen.dart:57-71。对 flutter_slidable-4.0.3/lib 执行
  `grep -rn 'Semantics'` 无任何匹配。
- 建议：在行尾提供显式“更多”菜单（PopupMenuButton）或长按菜单承载同样的动作，Slidable 仅作为快捷方式。
- 复核说明：本条未获证实为广泛问题，复核附注把有效范围大幅缩小：取消收藏清单/实体可经详情页
  FavoriteButton 完成（走同一 `_postCollect` 接口），取消关注标签有 FollowingTagsButton
  入口，取消收藏演员本就是可见按钮（collected_actors_screen.dart:
  167-180）；真正只靠滑动的是“我的清单”的改名/删除（my_lists_screen.dart:124、133）。此外 action 实现为
  OutlinedButton，并非“不产出任何 Semantics”，只是 pane 被收缩为零宽。

**UIUX-2｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/auth/screens/register_screen.dart:99
- 问题：注册/登录页用不可滚动的居中 Column 承载表单，键盘弹起或系统字号放大时内容溢出，提交按钮与错误提示被挤出可视区。
- 影响：Scaffold 默认 `resizeToAvoidBottomInset=true` 会按键盘高度压缩 body；注册页内容（3 个
  TextField + 主按钮 + 错误文案 + 去登录链接，约 440dp 加 48dp padding）在键盘弹起后可用高度常只剩
  300–400dp，触发 RenderFlex overflow；大字号下即使无键盘也会溢出。用户看不到“两次密码不一致”等错误提示，也难以点到“注册”。
- 证据：register_screen.dart:99-103
  `body: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [...]))`
  ，内部无 SingleChildScrollView/ListView；login_screen.dart:145-149 结构相同。test/features/auth/*
  .dart 中 `rg 'textScaler|viewInsets'` 无匹配。项目约定 .agents/rules/ui-ux.md:69 要求布局在较小屏幕上不溢出。
- 建议：用 SingleChildScrollView（配合 ConstrainedBox (minHeight: constraints.maxHeight) +
  IntrinsicHeight）或 ListView 承载表单。
- 复核说明：代码事实一致：两文件均无滚动容器、无 Expanded/Flexible；`grep resizeToAvoidBottomInset lib`
  无匹配，app.dart:48-54 的 builder 只包 AnnotatedRegion，无 textScaler 钳制。溢出量为按 widget
  树与布局规则的推算，未实测。

**UIUX-3｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/widgets/actor_card.dart:75
- 问题：选中态徽章用字面量 `Colors.white` 叠在 `colorScheme.primary` 上，暗色模式下对比度不足，且选中态没有暴露给读屏。
- 影响：暗色方案中 primary 取 tone 80（浅色），白色勾选图标对比度约 1.7:1，远低于 WCAG 1.4.11 非文本 3:
  1，暗色主题下“已选中”几乎不可辨认；该徽章用于 collected_actors_screen.dart:158
  的批量取消收藏编辑态，用户可能误判已选演员。actor_card.dart:39-41 的 Semantics 也没有
  selected，读屏无法获知选中状态。
- 证据：actor_card.dart:69-85
  `Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle), child: const Icon(Icons.check_circle, size: 20, color: Colors.white))`；:
  39-41 `Semantics(button: onTap != null, label: actor.name, child: ...)` 无 selected
  参数。色调依据：material_color_utilities-0.13.0 `primary ... s.isDark ? 80 : 40`、
  `onPrimary ... s.isDark ? 20 : 100`。同类硬编码见 magnet_list_tile.dart:132 `Colors.pink.shade50`。
- 建议：图标改用 `colorScheme.onPrimary`，Semantics 增加 `selected: selected`；徽章底色改用 ColorScheme
  角色（如 primaryContainer/onPrimaryContainer），删除字面量颜色。
- 复核说明：代码事实成立，影响略夸大：check_circle 是实心图形，暗色下白色圆盘仍醒目，真正失去可读性的是勾形（镂空露出
  tone 80 的 primary，约 1.7:1）；“几乎不可辨认、可能误判”偏重。读屏无选中状态属实，批量取消收藏属破坏性操作，该点影响真实。

**UIUX-4｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/widgets/rating_badge.dart:34
- 问题：排名徽章固定白色文字叠在金/银/铜底色上，对比度远低于 4.5:1，且数字没有语义说明。
- 影响：Top250 前 3 名白字与 #FFD700/#A8A9AD/#CD7F32 的对比度约 1.4:1 / 2.4:1 / 3.1:1，低于 WCAG AA
  4.5:1（.agents/rules/accessibility.md:5、ui-ux.md:235），弱视或强光下排名不可读；读屏只会读出孤立的“1”“2”，缺少“第
  N 名”上下文。
- 证据：rating_badge.dart:8-19 返回 #FFD700/#A8A9AD/#CD7F32；:23-38
  `Container(width: 22, height: 22, ... child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))`
  。使用点 movie_list_tile.dart:47-48，Top250 由 top250_tab.dart:146-149 传入 `rank=startRank+index`。
- 建议：按底色选择深色前景（如金牌用深棕），或改用满足 4.5:1 的徽章配色，并给徽章加
  `Semantics(label: '第 $rank 名')`。
- 复核说明：事实全部核实，对比度实算为 1.40:1 / 2.35:1 / 3.14:1，与原文一致；12px 粗体不属于大字号，确需
  4.5:1。影响面有限（仅 Top250 前 3 行，且名次仍有列表顺序暗示），维持中。

**UIUX-5｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/home/widgets/recommend_carousel.dart:86
- 问题：首页推荐轮播每 5 秒自动切换，没有暂停/停止入口，也不响应系统“减少动态效果”设置。
- 影响：WCAG 2.2.2（Level A）要求自动开始且持续超过 5 秒的移动内容提供暂停/停止/隐藏方式；
  `pauseAutoPlayOnTouch` 只在手指按住时暂停，松手即继续，`enableInfiniteScroll` 又让其无限循环，前庭/认知敏感用户无法关闭。
- 证据：recommend_carousel.dart:77-92
  `final canAutoPlay = widget.movies.length > 1; ... autoPlay: canAutoPlay, autoPlayInterval: const Duration(seconds: 5), autoPlayAnimationDuration: 400ms, enableInfiniteScroll: canAutoPlay, pauseAutoPlayOnTouch: true`；:
  27-30 的 `_shouldAutoPlay` 仅检查生命周期与 TickerMode；
  `rg 'disableAnimations|accessibleNavigation' lib` 无匹配（全仓未处理减少动效）。
- 建议：读取 `MediaQuery.disableAnimationsOf(context)`，为 true 时关闭 autoPlay，并在首页提供暂停/播放控制。
- 复核说明：成立。第三方源码佐证：carousel_slider.dart:281-292 按住清定时器、松手恢复；:130-131
  `Timer.periodic` 无限轮转，不消费 disableAnimations。首页 home_screen.dart:170-180
  直接放入轮播，无控制按钮；TickerMode 与 App 生命周期只是非用户可操作的减轻因素。

**UIUX-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/app.dart:37
- 问题：`MaterialApp.router` 未提供中文本地化，框架自带的无障碍标签保持英文。
- 影响：所有自动生成的 AppBar 返回按钮在读屏中播报为“Back”，未显式传 tooltip 的 PopupMenuButton
  播报为“Show
  menu”，与全中文界面混杂，违反项目“所有文案直接使用中文硬编码”（RULES.md）和无障碍标签要求（.agents/rules/accessibility.md:
  7）。
- 证据：app.dart:37-55 MaterialApp.router 只设置 theme/darkTheme/themeMode/routerConfig/builder，无
  `localizationsDelegates`；`rg 'flutter_localizations|localizationsDelegates' lib pubspec.yaml`
  无匹配。Flutter SDK 默认 supportedLocales 为 en_US、`backButtonTooltip => 'Back'`、
  `showMenuTooltip => 'Show menu'`。受影响控件：core/widgets/sort_select.dart:
  20-27、categories/widgets/category_filter_sheet.dart:
  29-38、actors/widgets/actor_movie_filter_sheet.dart:37-52。
- 建议：在不引入 .arb 的前提下提供最小中文 MaterialLocalizations delegate，或统一给
  BackButton/PopupMenuButton 显式传中文 tooltip。

### 3.10 播放器与详情页

预告片页的生命周期与设备副作用管理整体扎实：generation + identical 双重守卫、pause/dispose 各 1.5s
有界清理、lease 幂等释放、方向/沉浸/常亮/亮度的成对恢复，以及重试状态机（含“清理中只启动一次新驱动”）都能自洽；详情页四区块各自独立
ChangeNotifier、加载/失败/排序状态与 dispose 守卫也未发现并发错乱或状态错写。问题集中在自研操作层：底部进度条的
seek 映射用整屏宽度做分母（用户可见的定位错位），自动隐藏计时器在缓冲或暂停→恢复后不再重启。其次，剧照缩略图按
large_url 原图解码带来内存压力，播放初始化/play
抛错时会话被保留到重试或退出，另有两处低危问题（快退指示器丢失负号、进度条无无障碍语义）。本次未运行任何工具链命令（基线由工作流提供）；仓库代码与
docs 中没有任何预告片 CDN 或在线播放源需要 Referer 的依据，在线源播放交由系统浏览器打开，因此未把
Referer 列为发现。

**PLAY-1｜严重度：高｜复核状态：已复核（代码级）**

- 位置：lib/features/movie_detail/widgets/movie_preview_controls_overlay.dart:508
- 问题：底部进度条的点击/拖动 seek 用整屏宽度换算，seek 目标被压缩到进度条宽度占比，无法通过进度条定位到后段。
- 影响：390dp 屏上播放按钮占 48dp、时间文本及其内边距约占 100dp、行内边距 16dp，进度条实际只有约
  220dp（约屏宽的 57%）。点或拖到进度条最右端只会 seek 到约 57% 时长，视觉填充也不会跟随手指；视频后约
  40% 无法通过进度条到达，只能改用全屏横滑分多次接近。
- 证据：movie_preview_controls_overlay.dart:365
  `_gestureSize = Size(constraints.maxWidth, constraints.maxHeight)`（整屏尺寸）；:446
  `Expanded(child: _progressBar())`；:474 与 :480 `_seekToProgress(details.localPosition.dx)`（dx
  是进度条局部坐标）；:511 `final width = _gestureSize.width;`（却用整屏宽度作分母）。测试
  movie_preview_controls_overlay_test.dart:184-205 只断言 `seekPositions` 非空，没有校验目标位置。
- 建议：用进度条自身宽度（如 `_progressBar` 内 LayoutBuilder 的 `constraints.maxWidth` 或
  RenderBox.size.width）作为 seek 映射分母。
- 复核说明：成立。同一 `_progressBar` 内部 :492-495 已用 `constraints.maxWidth`
  作轨道宽度，两处分母不一致正是错位来源。唯一需修正的措辞：拖动可越出进度条边界，最远约 80-86%，并非严格
  57%，但“后段难以通过进度条到达、填充不跟手”的结论成立。无上层兜底，替代路径只有 :23 的
  horizontalSeekWindow=90s 整屏横滑。

**PLAY-2｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/movie_detail/widgets/movie_preview_controls_overlay.dart:140
- 问题：自动隐藏计时器只在 `_setVisible(true)` 真正改变状态时才重启；`_canAutoHide` 由 false 变回 true
  时没有重新计时，一次缓冲或暂停→恢复后操作层永久不再自动隐藏。
- 影响：播放中只要发生缓冲（初始缓冲尤其常见）或暂停再恢复：处于不可自动隐藏期间 `_onStateChanged` 调用
  `_setVisible(true)`，但 `_visible` 已是 true 会提前 return，`_resetHideTimer` 不执行；此前那次 Timer
  已到点且因 `_canAutoHide=false` 未隐藏。等恢复播放后没有任何路径重新建
  Timer，顶部栏与底部操作栏一直停在屏幕上，直到用户手动点两次切换显隐。
- 证据：movie_preview_controls_overlay.dart:87-92 `_canAutoHide` 要求 isPlaying && !isBuffering && !
  isCompleted && 无错误；:140-150 `_onStateChanged` 只有 `if (!_canAutoHide) _setVisible(true);`，没有
  else 分支重启计时；:152-161 `_setVisible` 首行 `if (_visible.value == visible) return;`；:163-171
  `_resetHideTimer` 只在 `_canAutoHide` 时建 Timer，Timer 回调里 `_canAutoHide` 为 false 时不做任何事。测试
  movie_preview_controls_overlay_test.dart:63 与 :78 分别只覆盖“稳定播放 3 秒自动隐藏”和“暂停时保持显示”。
- 建议：在 `_onStateChanged` 中检测 `_canAutoHide` 由 false 变 true 时调用 `_resetHideTimer()`
  （或直接按当前状态重启/取消计时）。
- 复核说明：成立，并补充一条更确定的路径：若 initState 时已处于缓冲（媒体初始缓冲常见），连初始 Timer
  都不会创建，恢复后同样永不自动隐藏。`_keepVisibleOnInteraction`（:174-176）也走 `_setVisible(true)`
  ，同样被 :153 提前返回；父层重建复用同一 State，didUpdateWidget 只处理 playback 身份变化，不会重建
  Timer。细微差别：若缓冲/暂停在旧 Timer 到点前结束，旧 Timer 仍会在恢复后触发隐藏，故“每次缓冲都永久失效”并非绝对。

**PLAY-3｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/movie_detail/widgets/basic_info_sections.dart:197
- 问题：详情页“预告片 / 剧照”164 高的横向缩略图直接使用 large_url 原图解码，未限制解码尺寸，大图内存与解码开销偏高（与
  PERF-2 同一问题）。
- 影响：normalize 时 `_imageUrl` 优先取 large_url，剧照缩略图与全屏图库共用这批大图地址；MovieStillThumbnail
  只给 onImageSize，未传 memCacheHeight，CachedImage 按原图分辨率解码，而 ImageSizeListener 又额外
  resolve 了一个 provider。长剧照列表滑动时每张 bitmap 可达数 MB～十几 MB，容易顶到默认 100MB
  ImageCache 上限导致反复解码、卡顿，低端机有 OOM 风险。
- 证据：api_data.dart:358-365
  `image['large_url'] ?? image['url'] ?? image['image_url'] ?? image['thumb_url']`
  ；basic_info_sections.dart:141 `height: 164`、:197-199
  `MovieStillThumbnail(urls[screenshotIndex], ...)`；movie_still_thumbnail.dart:71
  `CachedImage(widget.url, onImageSize: _handleImageSize)`（无
  memCacheWidth/Height）；cached_image.dart:42-44 自带约定“内存缓存位图的目标尺寸；小槽位应传入以避免解码整张原图”。
- 建议：剧照缩略图按槽位高度 × devicePixelRatio 传 memCacheHeight，并让尺寸监听使用同一个有界
  provider；全屏图库再按原图解码。
- 复核说明：核心结论成立，但“ImageSizeListener 又额外 resolve 了一个全尺寸 provider（即多一份全尺寸位图）”不准确：该
  provider 与 CachedNetworkImage 内部 provider 的 url/scale/maxWidth/maxHeight 完全相同，命中同一
  ImageCache 条目、共享同一份 ImageInfo，只是多了一个 ImageStream 监听。

**PLAY-4｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/movie_detail/screens/movie_preview_screen.dart:257
- 问题：播放初始化或 `play` 抛错时，已创建的 playback 仍挂在 `_session` 上不释放，只有用户点重试或退出页面才清理。
- 影响：进入“预告片播放失败”页后，media_kit 的 Player/VideoController
  以及已打开的原生解码资源会一直存活，错误页停留多久就占用多久；若初始化阶段已部分打开媒体流，还会额外占用内存与音频会话。
- 证据：movie_preview_screen.dart:238 `_session = session;` 先赋值，:239
  `await session.playback.initialize()`、:244 `await session.playback.play()`；:257-266 catch 里只有
  `!_isCurrentSession` 时才 `_detachAndCleanup(session)`，当前会话仅 `_showPageError()`；该会话的清理只发生在
  `_retry`（:275-278）与 dispose（:113-118）。测试 movie_preview_screen_test.dart:118-150
  也显示失败驱动在点重试时（:146）才 `disposeCalls=1`。
- 建议：初始化/play 失败时先对当前 session 执行 `_detachAndCleanup`（或至少 pause + dispose）再切到错误页。

**PLAY-5｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/movie_detail/widgets/movie_preview_controls_overlay.dart:631
- 问题：水平快退指示器丢弃了负号，后退偏移显示成与快进相同的正数文本。
- 影响：例如从 60s 后退到 45s，指示器显示目标 00:45 与偏移 00:15（只有图标变成 replay），而快进显示 +00:
  15；用户无法从文字分辨方向，与“实时显示目标位置与偏移量”的既有规格不一致。
- 证据：movie_preview_controls_overlay.dart:633 `final sign = off.isNegative ? '' : '+';`，:636
  `'${_formatDuration(target ?? Duration.zero)}\n$sign${_formatDuration(off.abs())}'`；同时
  `_formatDuration`（:663-670）本身已支持输出负号。
- 建议：负向时使用 `_formatDuration(off)`（或 sign 取 '-'），正向继续保留 '+'。

**PLAY-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/movie_detail/widgets/movie_preview_controls_overlay.dart:469
- 问题：底部进度条是纯 GestureDetector + 自绘容器，没有任何 Semantics/Slider 语义，读屏用户既无法获知也无法操作播放进度。
- 影响：TalkBack/VoiceOver 下进度条不可聚焦、不可调节，也读不出当前进度；播放页其余交互（返回、播放/暂停）有
  tooltip 语义，唯独核心的 seek 控件对无障碍用户不可用，与项目约定“为 UI 元素提供描述性语义、保证交互元素可被读屏到达”不符。
- 证据：movie_preview_controls_overlay.dart:469-506 `_progressBar()` 只包含
  GestureDetector、Container、FractionallySizedBox，全文件除 :402/:430 的 ExcludeSemantics 外没有
  Semantics/Slider；.agents/rules/accessibility.md:7-8 要求用 Semantics 提供描述性标签并确保所有交互元素可被读屏访问。
- 建议：用 `Semantics(slider: true, value/increasedValue/decreasedValue, onIncrease/onDecrease)`
  包裹进度条，或改用去掉轨道样式的 Slider。

### 3.11 个人中心与会话

个人中心与会话链路的骨架是健康的：会话落在 secure storage 并带 legacy 迁移、401
有全局登出+登录引导、启动有会话校验与关注标签同步、收藏/关注写操作失败都有提示且不做乐观更新、分页
reload 语义（清空+错误态）一致。问题集中在“占位页面直接对用户暴露”和几处失败兜底/一致性缺口：“我看过的”仍是永远空数据的占位页、隐藏的
Token 认证入口换账号不清关注缓存、secure 会话反序列化无兜底、退出登录无异常保护，另有 from
参数编码与错误文案两处小问题。以上结论全部来自静态阅读（未重复执行 analyze/test/format，基线采用工作流提供的数据）。

**USER-1｜严重度：高｜复核状态：已复核（代码级）**

- 位置：lib/router/app_router.dart:254
- 问题：“我看过的”路由仍指向占位页 ProfileMovieCollectionScreen，该页分页 fetch 恒定返回空页，页面永远显示“暂无数据”。
- 影响：用户实际有看过记录（个人页 subtitles 显示“我已看过 N 部影片”）时，点进去始终是空列表；顶部 6 个类型
  Tab 共用一个空 controller，筛选抽屉回调是空实现，整个页面没有任何可用数据路径，属于明确的用户可见错误行为。
- 证据：app_router.dart:253-263
  `path: AppRoutes.profileWatched ... child: const ProfileMovieCollectionScreen(title: '我看过的', filterButton: true)`
  ；profile_movie_collection_screen.dart:33-36
  `_controller = PaginationController<MovieSummary>(fetch: (page) async => const PagedResult(items: [], currentPage: 1, totalPages: 1, total: 0))`
  ，该类没有 dataSource 注入点；同文件 :66-81 `endDrawer: ... onChanged: _noopFilter`、:92
  `void _noopFilter(Map<String, String> _) {}`；profile_screen.dart:91-96 用 `watched_count` 做
  subtitle 并跳转该路由；test/core/router/app_router_requirements_test.dart:47-57
  的“我想看的”用例说明占位页已被判定弃用，但“我看过的”没有同步迁移（该页无任何测试覆盖）。
- 建议：与“我想看的”保持一致，改为 `ProfileReviewMoviesScreen(title: '我看过的', status: 'watched')`
  ，或给占位页接入真实数据源并实现 Tab/筛选。
- 复核说明：成立。补充：同文件 :82-86 将 6 个 Tab 全部映射到同一个 `_controller`，切换 Tab
  不改变数据；后端并非限制——docs/main/api/assist/authenticated.md:535,560 记录
  `GET /api/v2/users/review_movies?status=watched` 已实测可用，修复路径存在。

**USER-2｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/profile/screens/profile_settings_screen.dart:98
- 问题：版本号 5 连击打开的“认证 Token”弹窗通过 `auth.login` 直接替换账号身份，但没有像登录页那样清空/同步
  FollowingTagsProvider。
- 影响：换 token 后“我的关注”和类别页关注按钮仍显示上一账号的标签；用户点“取消关注”会拿上一账号的 tag
  id 发 DELETE（失败），而下次冷启动 startup 会把这批旧标签作为 batch_push 请求体推给新账号，属于跨账号的脏数据。
- 证据：profile_settings_screen.dart:96-99
  `TokenAuthenticationDialog(authenticate: service.authenticate, saveSession: auth.login)`；对照
  login_screen.dart:96-111 登录成功后会 `syncFromLogin(tags)`；following_tags_provider.dart:65-70
  `syncFromRemote()` 把本地 `_tags` 作为 batch_push 入参；startup_screen.dart:64-66
  启动时调用它；docs/superpowers/specs/2026-08-21-following-tags-design.md:159-164 明确要求“登出 /
  token 过期登出 → clear () 清空缓存（避免残留他人数据）”，而换 token 这条路径两者都没做。
- 建议：Token 认证成功保存会话后调用 `FollowingTagsProvider.clear()`，或按新 token 重新拉取后
  `syncFromLogin`。
- 复核说明：成立。`auth.login` 本身无副作用（auth_provider.dart:88-97 只 persist + 赋值 +
  notify）；关注缓存是全局单键 `key_following_tags`（storage_keys.dart:
  16），不按账号隔离；实际危害需“上一账号有关注标签 + 换成另一账号 token”，不涉及崩溃或凭据泄露。

**USER-3｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/providers/auth_provider.dart:36
- 问题：从 secure storage 读出的会话字符串被直接 `jsonDecode`，没有解析失败兜底。
- 影响：secure storage 内容损坏（如 Android keystore 失效、备份恢复后密文不可读）时
  `AuthProvider.create` 抛 FormatException，`main._bootstrap` 捕获后停在
  StartupFailureScreen，而“重试”会重跑同一次读取永远失败，应用彻底无法进入。
- 证据：auth_provider.dart:28-37 的 try 只兜住读取异常，紧接着 `p._restoreSession(jsonDecode(stored))`
  无 try/catch；main.dart:49-59 捕获后
  `runApp(StartupFailureScreen(error: error, onRetry: _bootstrap))`；对照 following_tags_store.dart:
  24-32 对畸形 JSON 有兜底。
- 建议：把 jsonDecode 包进 try/catch，解析失败按未登录处理并删除该键（或覆盖为 null 会话）。
- 复核说明：与 STATE-2/DATA-2/ERR-2 为同一缺陷。补充：lib/ 中没有任何对 `StorageKeys.authSession` 的
  delete 调用（`SecureValueStore.delete` 在 lib/ 内零调用），失败路径不清理坏键，故损坏值会永久复现；但“keystore
  失效”更可能表现为 read 抛异常并被 :31 吞掉，触发想象偏弱；auth_provider.dart:74 的 legacy 路径同样缺兜底。

**USER-4｜严重度：低｜复核状态：已复核（代码级）**

- 位置：lib/features/profile/screens/profile_screen.dart:136
- 问题：“退出登录”先清关注缓存、再 `await auth.logout()`，两步都没有异常保护（与 STATE-3 同一根因）。
- 影响：secure storage 写入失败时 `AuthProvider.logout()` 在 `_persist` 处抛出，内存 token
  不会清空，用户仍处于登录态但关注标签已被清空且无任何提示，异常从 onTap 异步回调逃逸；用户会看到“点了退出却毫无变化”。
- 证据：profile_screen.dart:136-138
  `await context.read<FollowingTagsProvider>().clear(); await auth.logout(); if (context.mounted) context.go('/home');`
  ；auth_provider.dart:110-120 的 logout 在写入失败时直接抛出，其后的
  `_token = null; notifyListeners();` 不会执行；对照 session_refresh_service.dart:67-73 的
  `_logoutBestEffort` 有 try/catch。
- 建议：用 try/catch 包裹整段登出逻辑（失败给出提示且不先清缓存），或先 `await auth.logout()` 成功后再清关注缓存。
- 复核说明：核心事实成立，两处影响需修正：a) “之后也无法恢复关注列表”不成立——重新登录时
  login_screen.dart:96-111 会 `syncFromLogin` 重新灌入，且清缓存未调用 unfollow
  接口，服务端关注关系未变，属本地缓存丢失而非数据丢失；b) 证据称 main.dart:80-84 的 onAuthError 是
  best-effort 包裹不准确，该处是 `unawaited(authProvider.logout())`，真正带 try/catch 的只有
  `_logoutBestEffort`。

**USER-5｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/auth/screens/register_screen.dart:69
- 问题：login 与 register 之间用字符串插值传递 from，且登录成功跳转时对已被 GoRouter 解码过的 from 再次
  `Uri.decodeComponent`。
- 影响：当 from 来自 `goLoginForAuthError`（含查询串，例如 `/common-list?id=1&category=m`）时，
  `/register?from=$from` 中的 `&` 会被解析成新参数；注册或返回登录后再跳转只剩 `/common-list?id=1`
  ，category 丢失，落到缺参的空列表页。
- 证据：app_router.dart:57-63 用
  `Uri(path: AppRoutes.login, queryParameters: {'from': from}).toString()`
  整体编码；login_screen.dart:113-114 `queryParameters['from']`（已解码）后再
  `Uri.decodeComponent(from)`；login_screen.dart:219
  `final to = hasFrom ? '/register?from=$from' : '/register';`；register_screen.dart:68-69、169-170
  同样直接插值。
- 建议：统一用 `Uri(path: ..., queryParameters: {'from': from}).toString()` 构造登录/注册地址，并去掉多余的
  `Uri.decodeComponent`。

**USER-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/auth/screens/login_screen.dart:121
- 问题：登录页（及注册页）对非 ApiException 的失败直接 `_error = e.toString()` 展示原始异常文本。
- 影响：断网、超时、DNS 失败等最常见的登录失败场景下，页面会显示英文 DioException
  详情（含内部实现细节），用户无法理解；与项目内其他页面的中文友好文案约定不一致。
- 证据：login_screen.dart:121-126
  `catch (e) { if (!mounted) return; setState(() { _error = e.toString(); _loading = false; }); }`
  ；register_screen.dart:77-82 相同写法；DioException 在网络错误时由 response_interceptor.dart:74-78
  `handler.next(err)` 原样抛出，不走 ApiException 分支；对照 profile_settings_screen.dart:153-157
  使用“检查更新失败，请稍后重试”。
- 建议：通用 catch 使用固定中文文案（如“登录失败，请检查网络后重试”），仅透出 ApiException.message
  这样的服务端文案。
- 说明：本条未单独复核，但其核心行为已在 ERR-1 的复核中得到证实（登录/注册通用 catch 展示原始异常），可与
  ERR-1 合并修复。

### 3.12 首页、搜索与分类浏览

逐文件读了 home/search/rankings/categories 四个模块，并顺着共用链路核对了
pagination_controller、movie_grid_view、paginated_list_view、api_data 的解析与 docs/main/api
下的接口契约。结构层面是健康的：四处列表都做了 Tab 保活，关键词变更用 `ValueKey(state.uri)` 重建结果页、筛选变更加
generation 防竞态、实体搜索用 SearchPageSession
做了跨页去重，这些没有可复现的竞态或状态串味。问题集中在分页终止条件与服务端契约不匹配（磁链分页无去重、榜单
totalPages 退化）、Top250 名次与末页判断，以及共享列表控件的错误重试/滚动物理；清单 `type=list`
的契约疑点经复核认为证据不足（见 LIST-2）。另外首页整体没有下拉刷新，只能靠各分区“换一组”和错误重试。

**LIST-1｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/search/services/magnet_search_service.dart:58
- 问题：磁链搜索分页恒宣称“还有下一页”，且整条分页链路没有跨页去重，越界或忽略 page 的响应会被无限重复追加。
- 影响：项目 API 文档记录 `/api/v1/search_magnet` 必填参数只有 q（无 page）、响应只有
  magnets/current_page，而同站点 `/api/v2/search` 的 typed 分支实测 page=1/2/3 返回完全相同结果集。若
  search_magnet 同样忽略 page，则 current_page 恒为 1，PaginationController 的 `_page` 不再前进而
  hasMore 恒真：用户每滚到底一次就再追加一整页相同磁链，列表无限增长、请求不停。
- 证据：`totalPages: items.isNotEmpty ? currentPage + 1 : currentPage`；pagination_controller.dart:
  41-47 无条件 `_items.addAll(result.items)` 且 `_hasMore = _page < result.totalPages`；触发点
  magnet_search_results_screen.dart:158-167（ScrollEnd →
  fetchMore）。文档：docs/main/api/assist/public/search-and-filters.md:86-97 与 :44-49；对照
  search_screen_session.dart:10-23 实体搜索的 seenIds 去重。
- 建议：复用 `SearchPageSession<Magnet>`（按 hash/id 去重、增量为空即终止），并给页码加不回退保护。
- 复核说明：本条未获证实。代码事实（恒 `currentPage+1`、无去重）属实，但“无限重复追加”依赖一个仓库内无法证实的服务端前提：search_magnet
  忽略 page。相反，文档与 openapi schema 都声明响应包含 `current_page`
  ，且设计文档（2026-08-03-magnet-search-design.md:78）明确该“探测下一页”是有意设计，测试也把“非空则探测、空页即停”写成契约。当前可成立的是“缺少按
  hash 去重与页码不回退保护”，属加固建议；且空响应时 `totalPages==currentPage`，hasMore 会变
  false，终止路径设计上可达。

**LIST-2｜严重度：低｜复核状态：待确认（未独立复核；复核附注实质否证其前提）**

- 位置：lib/features/search/services/search_entity_service.dart:122
- 问题：清单搜索 Tab 请求 `/api/v2/search?type=list`，但接口的 type 枚举与响应实体都没有 list 分支，该
  Tab 必然拿不到数据。
- 影响：服务端若忽略未知 type 会回落到默认 movie 分支，响应中没有 lists，Tab
  永远显示“暂无清单”；若做枚举校验则直接报错并把原始异常显示给用户。两条路径下清单搜索都不可用，且是静默空态。
- 证据：`type: 'list', collectionKey: 'lists'`（search_entity_service.dart:
  122-132）；docs/main/api/jdb_api_openapi.json:1891-1899 的 enum 只有
  movie/actor/series/maker/director/code；docs/main/api/assist/public/search-and-filters.md:24-40
  的已验证分支同样没有 list；Tab 装配见 search_results_screen.dart:207-216。
- 建议：改用清单真实支持的入口（如 `/api/v1/lists`）或改为按关键字本地过滤；都不行就移除该 Tab。
- 复核说明：本条前提不成立，不应作为确定缺陷。同一份 openapi 的 `SearchNewEntity`（6556 行起）明确包含
  `lists` 且描述为“片单结果”，即 cited evidence 自身推翻“响应实体没有 list 分支”；type 枚举确实不含
  list，但 findings 的“回落 movie /
  枚举报错”两条路径均属推测，仓库内无实测记录。项目设计契约反而明确规定“清单 | type=list | lists |
  ListModel”（docs/superpowers/specs/2026-08-03-search-entity-tabs-design.md:
  29-42）。建议先做一次线上验证再决定是否关单或移除 Tab。

**LIST-3｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/rankings/services/ranking_service.dart:92
- 问题：`totalPages: apiInt(m['total_pages'], fallbackPage)` 在响应缺少 total_pages
  时把总页数等同于本次请求的页码，导致榜单第一页之后 hasMore 立即为 false。
- 影响：文档记录 `/api/v1/rankings` 只观察到 movies/current_page（无 total_pages），于是有码/无码/欧美/FC2
  四个榜单 Tab 滚到底也停在第一页：服务端支持 page 参数，客户端却永远不会请求第 2 页，榜单内容被静默截断且没有任何提示。
- 证据：`getRanking` 传 `fallbackPage: page`（ranking_service.dart:59），`_parseMoviePage` 在 :91-92 用同一
  fallback 计算 currentPage/totalPages；使用方 rank_tabs.dart:131-135 + MovieGridView 无限滚动。对照
  api_data.dart:395-397：缺 total_pages 时按“满页则 +1”推断。文档
  docs/main/api/assist/public/movies.md:271-274、:275-282。
- 建议：缺少 total_pages 时按 `items.length >= pageSize ? page + 1 : page` 推断（对齐
  apiPageResult），并保留服务端 current_page 前移的判断。
- 复核说明：成立。链路：pagination_controller.dart:47 `_hasMore = _page < result.totalPages`，:30 在 !
  hasMore 时直接 return，movie_grid_view.dart:72-78 是唯一翻页触发点；四个 Tab 全部走
  getRanking，无上层补偿（对照 top250_tab.dart:47-54 自算 totalPages 的写法）。残余不确定性：服务端实况是否真不带
  total_pages 只能依据文档观察；但 fallback 设计本身是退化的，任何无该字段的信封都必然无法翻页。

**LIST-4｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/rankings/widgets/top250_tab.dart:148
- 问题：Top250 名次用 `startRank + index` 位置推算，而开启“未标看过”后服务端会剔除已看影片，响应里的真实
  ranking 字段又被丢弃。
- 影响：打开筛选面板的“未标‘看过’”后，返回列表的真实名次不连续（如 1,4,7…），UI 仍按 1,2,3
  编号，名次展示错误；此外过滤后一页往往不足 50 条，`:47-48` 的 `items.length < _pageSize` 会直接判为最后一页，第
  51 名之后的未看影片不再加载。
- 证据：`:148 rank: widget.filter.startRank + index`；
  `:47-48 isLastPage = result.items.length < _pageSize || page >= _logicalTotalPages`；开关
  top250_filter_sheet.dart:87-93，请求参数 top250_tab.dart:44（ignore_watched）。接口文档：
  `ignore_watched` 为“是否排除已看过影片”，响应“data 为 MovieEntity 数组（含 ranking / generated_at
  字段）”；而 movie.dart:9-26 的 MovieSummary 不解析 ranking。
- 建议：解析响应 ranking 字段并用它渲染名次；末页判断不要只依赖“不足一页”，应按 start_rank 上限或 total
  收敛。
- 复核说明：成立。movie.g.dart:11-21 与 normalizeMovieSummaryJson（api_data.dart:76-89）均未补
  ranking，RankingService 也只返回 PagedResult<MovieSummary>。设计文档与测试夹具均按“不足 50
  条即末页”“startRank+index 显示名次”实现，未考虑 ignore_watched，测试只断言了请求参数。服务端在
  ignore_watched=true 时是否真的返回短页/带空洞名次依赖 OpenAPI 语义，未实网验证；但客户端无条件丢弃权威
  ranking 这一点本身已是确定缺陷。

**LIST-5｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/core/widgets/paginated_list_view.dart:36
- 问题：加载更多失败后，滚动监听没有 error 守卫，仍在每个 ScrollUpdateNotification 中调用 fetchMore，而
  fetchMore 开头会清空 error。
- 影响：一次加载更多失败后，用户每次滑动（含惯性滚动逐帧通知）都会立刻重发同一次请求：错误被清空 →
  底部“重试”按钮被替换成 loading → 再失败又出现，同时持续打服务端。搜索实体
  Tab（系列/片商/导演/清单/番号）、类别页与最新列表都走这条共享路径。
- 证据：paginated_list_view.dart:34-42（ScrollUpdate/ScrollEnd + extentAfter<200 → fetchMore，无 error
  判断）；movie_grid_view.dart:72-78 同样无守卫；pagination_controller.dart:36 每次 fetchMore 开头
  `_error = null`。同项目已有正确写法：top250_tab.dart:121-123、magnet_search_results_screen.dart:
  160-163 均带 `_controller.error == null`。
- 建议：两处滚动监听都加上 `controller.error == null && controller.hasMore` 守卫，失败后只允许用户点按钮重试。
- 复核说明：成立。补充：pagination_controller.dart:30 的入口守卫只有 `_isLoading || !_hasMore`，不含
  error，失败后 `_hasMore` 仍为 true；`paginated_list_view.dart:33` 的 hasTail 含 error，:50-62 在
  isLoading 时渲染 spinner、否则渲染“重试”，故失败后滚动会把按钮换成 loading。同一缺陷还存在于
  actor_grid_view.dart:88-94（演员搜索
  Tab），原发现未列出。措辞修正：“重试按钮几乎点不中”偏重——用户停止滚动后不再产生通知，按钮可正常点击；核心机制是“在底部持续滚动/惯性滚动时错误被清空并连续自动重发请求”。

**LIST-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/core/widgets/movie_grid_view.dart:83
- 问题：MovieGridView 的 CustomScrollView 未设置
  AlwaysScrollableScrollPhysics，内容不足一屏时不会产生可滚动区域，收不到滚动通知。
- 影响：筛选/搜索后只有一两行结果的网格在 Android 上无法下拉刷新（RefreshIndicator 永远不出现），此时若
  hasMore 仍为真也没有滚动事件能触发加载更多——即列表变短后既不能刷新也不能续页；Top250Tab 已显式设置该
  physics，网格这条路径被漏掉。
- 证据：
  `:79-84 RefreshIndicator(onRefresh: ... child: Stack(children: [CustomScrollView(controller: _scrollController, slivers: ...)]))`
  未传 physics；对照 top250_tab.dart:130 `physics: const AlwaysScrollableScrollPhysics()`。受影响页面：搜索影片
  Tab（search_result_tabs.dart:130）、类别页（categories_screen.dart:248）、最新列表（latest_type_tab.dart:
  116）、四个榜（rank_tabs.dart:104,174）。
- 建议：给该 CustomScrollView 补 `physics: const AlwaysScrollableScrollPhysics()`。

### 3.13 其余模块与可维护性

这 8 个模块功能完整、注释密度高：无 TODO/FIXME，最大文件 335 行（actors_screen.dart），两个 0
覆盖率的弹窗（actor_info_sheet、actor_movie_filter_sheet）逐行读过也未发现逻辑缺陷（只缺测试）。问题集中在结构层：片商/导演/系列是被复制三遍的同一份垂直切片，实体
JSON 归一化有 4 份逐字节相同的实现（复核补为 5 份），settings feature 整个是无人引用的遗留模块却在
STRUCTURE.md 里被当作现役功能描述，另有实体类别码与演员路由裸字符串的漂移风险。整体是“可运行但重复与文档漂移累积”，未发现崩溃/数据丢失级问题；本轮按约定未运行
flutter/dart/test，所有结论来自读码与 grep/diff 比对，测试与覆盖率数据采用任务给定基线。

**MOD-1｜严重度：中｜复核状态：已复核（代码级）**

- 位置：lib/features/makers/screens/makers_screen.dart:82
- 问题：片商/导演/系列三个 feature 各自复制了一套完全相同的“Tab + 分页列表”垂直切片：三段 44 行私有
  Tab 组件逐行相同，makers 与 directors 的 Screen 归一化后仅 3 行不同，两个 Service 归一化命名后 0
  行差异。
- 影响：分页、空态、错误处理或 KeepAlive 行为任一处修复都要改 3 次；且 Screen 的 TabController 长度取自
  tabs，而 TabBarView 子项由另一个平行常量列表（series 甚至是 1 + types）拼出，两个 const
  列表一旦不同步，Flutter 会在 post-frame 抛 FlutterError（TabBarView 长度不匹配），release 下断言被裁掉则退化为
  Tab 与内容错位。
- 证据：逐行比对：`_MakersTab`(makers_screen.dart:82-125) / `_DirectorsTab`(directors_screen.dart:
  82-125) / `_SeriesTab`(series_screen.dart:103-146) 三段完全相同；makers 与 directors Screen 仅
  22-23 行的 tabs/types 与 69 行的 category 'm'/'d' 不同；maker_service.dart 与 director_service.dart
  归一化命名后 diff 为 0 行。长度来源：makers_screen.dart:31 `TabController(length: tabs.length…)` +
  52-75 children 由 types 生成；series_screen.dart:32 + 53-97 children 为 1 个 letters + types（tabs 5
  项 / types 4 项）。框架断言见 Flutter 3.44.8 tabs.dart:2505-2520。违反 STRUCTURE.md §1 与
  RULES.md“公共能力单独成层”。
- 建议：在 core 抽一个泛型实体列表屏（title/emptyMessage +
  `List<({String label, PageFetcher<T> fetch, Widget Function(T) tile})>`），三个 feature 只保留数据源与
  tile 构造；影片类型标签收敛为 core 枚举，TabController 长度统一取 `children.length`。
- 复核说明：成立。独立 diff 验证三段 Tab 组件归一化后完全相同（各 44 行）；makers 与 directors 实际只剩 3
  行不同（原发现称 4 行，轻微夸大）；两个 Service 归一化后 diff 退出码 0。需纠正：三个屏幕当前 tabs 与
  children 长度全部一致，不会触发 post-frame 断言；该崩溃/错位只是后续改常量时的潜在风险，现有 widget
  测试在 debug 下大概率会先暴露长度不匹配。

**MOD-2｜严重度：低｜复核状态：已复核（代码级）**

- 位置：lib/core/network/api_data.dart:107
- 问题：实体 JSON 归一化逻辑以完全相同的 9 行代码存在 4 份：`normalizeMakerJson`、
  `normalizeDirectorJson`、`series_service._seriesJson`、`collections_service._namedEntityJson`。
- 影响：Maker/Director/Series 共用同一套字段兜底（id/name/type/movie_count，并兼容
  movie_count/movies_count/videos_count 三种来源）。接口字段改名或新增兜底时漏改任一副本，该条链路就会显示空名称/0
  部影片；出错点分散在 core/network、core/services、features/series 三处，维护成本高。
- 证据：用 Python 对四段函数体做逐行比对，maker==director==seriesJson==namedEntityJson 全部为
  True：api_data.dart:107-116、api_data.dart:118-127、series_service.dart:
  70-79、collections_service.dart:205-214。对应模型也几乎同构：maker.dart 与 director.dart
  字段集合完全一致，series.dart 仅少 avatarUrl。
- 建议：在 core/api_data.dart 提供一个 `normalizeNamedEntityJson`，`normalizeMakerJson`/
  `normalizeDirectorJson` 改为委托，series_service 与 collections_service 删除本地副本。
- 复核说明：核心事实成立，但需修正：重复实为 5 份，原发现漏了 search_entity_service.dart:145-154 的
  `_namedEntityJson`（内容同样一致，且同文件 :156-165 还有一份 `_codeJson` 宜一并合并）。原称“series 与
  collections 的副本无独立测试”一半错误：series 的 `videos_count`
  映射有专门测试（series_service_test.dart:49-68、:70-95），search 的副本也被覆盖；真正无兜底键覆盖的只有
  collections 的副本。当前五份实现完全一致且各自被测试验证，无链路会返回空名称或 0 部影片，属可维护性问题。

**MOD-3｜严重度：低｜复核状态：已复核（代码级）**

- 位置：lib/features/settings/screens/settings_screen.dart:6
- 问题：features/settings 整个模块（settings_screen.dart、setting_item.dart、index.dart，共 84 行）在任何
  lib/test 代码中都没有引用，是遗留死代码；真实设置页是 profile 的 ProfileSettingsScreen，而
  STRUCTURE.md:75 仍把“外观、线路、默认筛选标签、清除缓存”记在 settings feature 名下。
- 影响：维护者按 STRUCTURE.md 会进入一个未被路由的目录，只看到一个 53 行、只做主题下拉的页面，容易在此重复实现设置项（其主题下拉与
  ProfileSettingsScreen 的外观模式选择功能重复，改在这里不会生效）。文档列出的 4 项能力中 3 项实际在
  profile、1 项（默认筛选标签）全项目不存在，按文档排查会走空。
- 证据：`grep -rn "features/settings" lib test` 只命中该文件自身 import（settings_screen.dart:4）；
  `grep -rn "SettingItem" lib test` 只在该模块内。路由只有 routes.dart:51 `/profile/settings` →
  app_router.dart:335 ProfileSettingsScreen；外观/线路/清除缓存分别实现于
  profile_settings_screen.dart:255、269、276；`grep -rn "默认筛选" lib` 无命中。项目自有文档
  docs/comet/archive/2026-10-21-detail-online-play-sources/brief.md:38 已写明“不改
  lib/features/settings/（项目中的死代码目录，真设置页在 features/profile）”。
- 建议：删除 lib/features/settings/（含 index.dart），或让它接管真正的设置页；同时修正 STRUCTURE.md:75
  的能力描述与 settings 行。
- 复核说明：与 ARCH-3 为同一问题（此处从可维护性层记录）。事实全部成立：行数 1+53+30=84；全仓无非 .dart
  代码入口；profile_settings_screen.dart:347 与死代码 settings_screen.dart:39 调用同一
  ThemeProvider，确属能力重复。

**MOD-4｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/common/screens/common_list_screen.dart:124
- 问题：实体类别码以裸字符串 'm'/'s'/'d'/'c'/'l'/'a' 散落在至少 5 个模块；common 的 `_loadCollected`
  还重复维护了一份与 core 相同的类别集合，而这份集合是纯冗余。
- 影响：core 的 `FavoritesService.getHasCollected` 对未登记类别本就返回 null 且不发请求，所以本地集合删掉行为不变；一旦
  core 增加类别（或调整编码），common 侧不同步就会静默不显示收藏按钮（null →
  按钮不渲染，无任何报错），排查成本高。裸码写错同样只表现为静默失效。
- 证据：common_list_screen.dart:123-131 的 `const {'m','s','d','c','l','a'}` set；权威映射在
  core：collections_service.dart:176-183 `_detailPathByCategory` 与 186-188“entityPath == null 直接
  return null（不发请求）”。同一批裸码的复制点：series_screen.dart:69,90；makers_screen.dart:
  69；directors_screen.dart:69；actor_service.dart:24 `setCollected('a', …)`。
- 建议：在 core 定义 EntityCategory 枚举（code + endpoint）供路由与各列表页统一引用；删除 common 的
  supported 集合，直接依赖 `getHasCollected` 的 null 语义。

**MOD-5｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：lib/features/actors/screens/actors_screen.dart:206
- 问题：演员详情路由以裸字符串 `'/actor/${id}'` 手写在 5 处，绕过 lib/router/routes.dart:17 已存在的
  `AppRoutes.actorDetail`，且项目缺少与该模式串配套的 location 构造函数。
- 影响：路由改名或加前缀时这 5 处没有编译期保护，运行时无法匹配路由，表现为点击演员无反应；id 也未做
  `Uri.encodeComponent`（当前 id 为数字所以尚未暴露）。对比 movie 预览已有
  `AppRoutes.moviePreviewLocation` 做统一拼装与编码，说明这是约定内的缺口。
- 证据：裸串位置：actors_screen.dart:206、actors_screen.dart:294、search_result_tabs.dart:
  181、collected_actors_screen.dart:159、movie_detail_screen.dart:407；常量 routes.dart:17
  `actorDetail = '/actor/:id'`；routes.dart:31-35 提供
  moviePreviewLocation/historyRecommendDetailLocation（内部 `Uri.encodeComponent`），唯独演员没有
  location helper。
- 建议：在 AppRoutes 增加 `actorDetailLocation(String id)`（内部 `Uri.encodeComponent`）并替换这 5 处。

**MOD-6｜严重度：低｜复核状态：待确认（未独立复核）**

- 位置：README.md:3
- 问题：README 的版本号与测试规模停留在旧值：写“当前版本 0.11.2”，实际 pubspec.yaml:19 为
  0.16.3+1603；README.md:62 写“约 850 个”测试用例，与当前基线 1005 个不符。
- 影响：对外说明与代码不一致，用户/贡献者据此判断版本与测试规模会得到错误信息；版本唯一修改点是
  pubspec.yaml，README 的版本属于每次发布都要手工同步、且已漂移 5 个 minor 的易漏项。
- 证据：README.md:3 与 pubspec.yaml:19；README.md:62 与任务基线“flutter test --no-pub：1005
  个测试全部通过”（本轮未重跑测试，采用给定基线）。
- 建议：README 的版本改为引用 pubspec 或省略具体值，测试规模改为“1000+”，并把 README 版本同步列入发布检查清单。

## 四、问题清单

| 编号    | 维度                 | 位置                                                                      | 问题                                                           | 严重度 | 复核状态 |
|---------|----------------------|---------------------------------------------------------------------------|----------------------------------------------------------------|--------|----------|
| BASE-1  | 工程基线             | 整个仓库（lib 与 test）                                                   | dart format 未通过：lib 34/249、test 49/157 个文件需格式化     | 低     | 已复核   |
| SEC-1   | 安全与网络层         | lib/core/network/startup_api_client.dart:21                               | 启动接口 baseUrl 硬编码 fallback，绕过域名轮转                 | 高     | 已复核   |
| SEC-2   | 安全与网络层         | lib/core/network/interceptors/domain_switch_interceptor.dart:42           | `_retried` 进程级粘滞，只能轮转一次且并发可双跳                | 高     | 已复核   |
| SEC-3   | 安全与网络层         | lib/core/network/domain_manager.dart:77                                   | 服务端下发域名零校验即作 baseUrl，Token 随之外发               | 中     | 已复核   |
| SEC-4   | 安全与网络层         | lib/core/network/interceptors/response_logging_interceptor.dart:95        | 登录成功响应含 JWT 明文进入 debug 日志                         | 低     | 待确认   |
| SEC-5   | 安全与网络层         | lib/core/network/interceptors/domain_switch_interceptor.dart:52           | 轮转重试失败包成 badResponse，丢 response 与原错误类型         | 低     | 待确认   |
| SEC-6   | 安全与网络层         | lib/core/network/api_client.dart:36                                       | 缺 sendTimeout，上传类请求可能无限挂起                         | 低     | 待确认   |
| STATE-1 | 状态管理与启动装配   | lib/main.dart:95                                                          | 启动装配固定兜底域名，重试不换域（同 SEC-1）                   | 高     | 已复核   |
| STATE-2 | 状态管理与启动装配   | lib/core/providers/auth_provider.dart:36                                  | 会话解码无 try/catch，坏值导致永久启动失败                     | 中     | 已复核   |
| STATE-3 | 状态管理与启动装配   | lib/core/providers/auth_provider.dart:114                                 | logout 先写后清，写失败无法登出且调用方已清缓存                | 中     | 已复核   |
| STATE-4 | 状态管理与启动装配   | lib/router/app_router.dart:355                                            | AuthGuard 只判一次、无 refreshListenable，登出后可返回受保护页 | 中     | 已复核   |
| STATE-5 | 状态管理与启动装配   | lib/main.dart:93                                                          | FollowingTagsProvider.initialize 被 unawaited，无并发去重      | 低     | 待确认   |
| STATE-6 | 状态管理与启动装配   | lib/core/providers/following_tags_provider.dart:42                        | 先改字段再 await 持久化再 notify，写失败不通知                 | 低     | 待确认   |
| DATA-1  | 数据模型与序列化     | lib/core/models/startup.g.dart:28                                         | 热词/settings/user 严格强转，字段漂移阻断启动                  | 中     | 已复核   |
| DATA-2  | 数据模型与序列化     | lib/core/providers/auth_provider.dart:74                                  | 旧版会话/用户解码无保护（同 STATE-2）                          | 中     | 已复核   |
| DATA-3  | 数据模型与序列化     | lib/features/rankings/services/ranking_service.dart:67                    | 裸 `as Map` 绕过 apiMap 容错                                   | 低     | 待确认   |
| DATA-4  | 数据模型与序列化     | lib/core/models/movie.g.dart:116                                          | MovieDetail.toJson 不能往返且丢 tagItems/review                | 低     | 待确认   |
| DATA-5  | 数据模型与序列化     | lib/features/profile/screens/profile_screen.dart:59                       | 用户名字符串取 [0]，空串抛 RangeError                          | 低     | 待确认   |
| ARCH-1  | 架构与规范合规       | lib/features/categories/screens/categories_screen.dart:11                 | categories/profile 横向依赖 following                          | 中     | 已复核   |
| ARCH-2  | 架构与规范合规       | lib/core/widgets/search_entry.dart:3                                      | core/feature 反向依赖 lib/router/routes.dart，文档自相矛盾     | 低     | 已复核   |
| ARCH-3  | 架构与规范合规       | lib/features/settings/index.dart:1                                        | settings feature 死代码，与真实设置页并存                      | 中     | 已复核   |
| ARCH-4  | 架构与规范合规       | lib/features/movie_detail/services/movie_preview_lease.dart:19            | Lease 抽象无人引用                                             | 低     | 待确认   |
| ARCH-5  | 架构与规范合规       | lib/core/network/api_client.dart:13                                       | api_client 与 auth_interceptor import 成环                     | 低     | 待确认   |
| ARCH-6  | 架构与规范合规       | lib/features/home/index.dart:5                                            | index.dart 过度导出内部 service/model                          | 低     | 待确认   |
| TEST-1  | 测试质量与覆盖       | test/features/auth/register_screen_test.dart:29                           | 注册提交链路零覆盖，API 用例未调用 service                     | 中     | 已复核   |
| TEST-2  | 测试质量与覆盖       | test/features/actors/actor_detail_screen_test.dart:74                     | 演员筛选/信息面板 0 覆盖                                       | 中     | 已复核   |
| TEST-3  | 测试质量与覆盖       | test/core/widgets/cached_image_test.dart:31                               | 三条 URL/尺寸测试只断言 widget 存在                            | 中     | 已复核   |
| TEST-4  | 测试质量与覆盖       | lib/main.dart:49                                                          | 启动失败兜底链路无测试                                         | 低     | 已复核   |
| TEST-5  | 测试质量与覆盖       | lib/features/movie_detail/widgets/save_to_list_sheet.dart:142             | 存入清单失败/回滚无测试                                        | 低     | 已复核   |
| TEST-6  | 测试质量与覆盖       | test/features/profile/collected_entities_page_test.dart:85                | 收藏实体页仅覆盖片商一类，清单取消收藏未测                     | 低     | 待确认   |
| PERF-1  | 性能与资源生命周期   | lib/core/network/image_decryptor.dart:45                                  | 逐字节展开 + 多次整图复制，UI isolate                          | 低     | 已复核   |
| PERF-2  | 性能与资源生命周期   | lib/core/widgets/movie_still_thumbnail.dart:71                            | 剧照按原图解码常驻 ImageCache                                  | 中     | 已复核   |
| PERF-3  | 性能与资源生命周期   | lib/features/categories/screens/categories_screen.dart:73                 | 分页 tick 触发整页 setState                                    | 低     | 已复核   |
| PERF-4  | 性能与资源生命周期   | lib/features/categories/services/category_tab_controller.dart:112         | 筛选 chip 每次点击立即请求，不合并/取消                        | 低     | 待确认   |
| PERF-5  | 性能与资源生命周期   | lib/core/widgets/pagination_controller.dart:20                            | items getter 每次全量复制列表                                  | 低     | 待确认   |
| PERF-6  | 性能与资源生命周期   | lib/features/movie_detail/screens/movie_detail_screen.dart:355            | 两处 ChangeNotifier 未 dispose                                 | 低     | 待确认   |
| ERR-1   | 错误处理与健壮性     | lib/features/auth/screens/login_screen.dart:115                           | `on ApiException` 不可达，登录注册展示 DioException 原文       | 高     | 已复核   |
| ERR-2   | 错误处理与健壮性     | lib/core/providers/auth_provider.dart:36                                  | 会话解码无容错（同 STATE-2）                                   | 中     | 已复核   |
| ERR-3   | 错误处理与健壮性     | lib/core/network/interceptors/domain_switch_interceptor.dart:32           | `_retried` 不复位（同 SEC-2）                                  | 中     | 已复核   |
| ERR-4   | 错误处理与健壮性     | lib/core/widgets/movie_grid_view.dart:59                                  | 多处 `error.toString()` 作为用户文案                           | 中     | 已复核   |
| ERR-5   | 错误处理与健壮性     | lib/features/actors/screens/actor_detail_screen.dart:141                  | 演员详情失败无重试、仅 `Text(_error!)`                         | 中     | 已复核   |
| ERR-6   | 错误处理与健壮性     | lib/core/widgets/review_tile.dart:80                                      | 点赞失败一律提示“已点过赞”                                     | 低     | 待确认   |
| UIUX-1  | UI 一致性与可访问性  | lib/features/profile/screens/collected_lists_screen.dart:117              | 破坏性操作只在 Slidable（有效范围经复核缩小）                  | 低     | 待确认   |
| UIUX-2  | UI 一致性与可访问性  | lib/features/auth/screens/register_screen.dart:99                         | 表单不可滚动，键盘/大字号溢出                                  | 中     | 已复核   |
| UIUX-3  | UI 一致性与可访问性  | lib/core/widgets/actor_card.dart:75                                       | 白勾选叠 primary，暗色对比度不足、选中态无语义                 | 中     | 已复核   |
| UIUX-4  | UI 一致性与可访问性  | lib/core/widgets/rating_badge.dart:34                                     | 白字叠金/银/铜，对比度 1.4–3.1:1，无“第 N 名”语义              | 中     | 已复核   |
| UIUX-5  | UI 一致性与可访问性  | lib/features/home/widgets/recommend_carousel.dart:86                      | 轮播 5s 自动切换，无暂停、不响应减少动效                       | 中     | 已复核   |
| UIUX-6  | UI 一致性与可访问性  | lib/app.dart:37                                                           | 无中文本地化，框架标签保持英文                                 | 低     | 待确认   |
| PLAY-1  | 播放器与详情页       | lib/features/movie_detail/widgets/movie_preview_controls_overlay.dart:508 | seek 用整屏宽度作分母，后段无法定位                            | 高     | 已复核   |
| PLAY-2  | 播放器与详情页       | lib/features/movie_detail/widgets/movie_preview_controls_overlay.dart:140 | 缓冲/暂停恢复后自动隐藏计时器不重启                            | 中     | 已复核   |
| PLAY-3  | 播放器与详情页       | lib/features/movie_detail/widgets/basic_info_sections.dart:197            | 剧照缩略图原图解码（同 PERF-2）                                | 中     | 已复核   |
| PLAY-4  | 播放器与详情页       | lib/features/movie_detail/screens/movie_preview_screen.dart:257           | 初始化/play 失败不释放 session                                 | 低     | 待确认   |
| PLAY-5  | 播放器与详情页       | lib/features/movie_detail/widgets/movie_preview_controls_overlay.dart:631 | 快退指示器丢失负号                                             | 低     | 待确认   |
| PLAY-6  | 播放器与详情页       | lib/features/movie_detail/widgets/movie_preview_controls_overlay.dart:469 | 进度条无 Slider/Semantics 语义                                 | 低     | 待确认   |
| USER-1  | 个人中心与会话       | lib/router/app_router.dart:254                                            | “我看过的”指向占位页，恒为空                                   | 高     | 已复核   |
| USER-2  | 个人中心与会话       | lib/features/profile/screens/profile_settings_screen.dart:98              | Token 换号不清关注缓存，冷启动把旧标签推给新账号               | 中     | 已复核   |
| USER-3  | 个人中心与会话       | lib/core/providers/auth_provider.dart:36                                  | secure 会话解码无兜底（同 STATE-2）                            | 中     | 已复核   |
| USER-4  | 个人中心与会话       | lib/features/profile/screens/profile_screen.dart:136                      | 退出登录先清缓存且无异常保护（同 STATE-3）                     | 低     | 已复核   |
| USER-5  | 个人中心与会话       | lib/features/auth/screens/register_screen.dart:69                         | from 参数插值 + 二次解码，查询串丢失                           | 低     | 待确认   |
| USER-6  | 个人中心与会话       | lib/features/auth/screens/login_screen.dart:121                           | 登录/注册通用 catch 展示原始异常                               | 低     | 待确认   |
| LIST-1  | 首页、搜索与分类浏览 | lib/features/search/services/magnet_search_service.dart:58                | 磁链分页恒称有下页且全链路无去重（服务端前提未证实）           | 低     | 待确认   |
| LIST-2  | 首页、搜索与分类浏览 | lib/features/search/services/search_entity_service.dart:122               | 清单搜索 type=list 的契约疑点（复核认为前提不成立）            | 低     | 待确认   |
| LIST-3  | 首页、搜索与分类浏览 | lib/features/rankings/services/ranking_service.dart:92                    | 缺 total_pages 时退化，榜单只加载第一页                        | 中     | 已复核   |
| LIST-4  | 首页、搜索与分类浏览 | lib/features/rankings/widgets/top250_tab.dart:148                         | Top250 名次按位置推算，过滤后错位/提前截断                     | 中     | 已复核   |
| LIST-5  | 首页、搜索与分类浏览 | lib/core/widgets/paginated_list_view.dart:36                              | 加载失败后滚动监听无 error 守卫，反复重发                      | 中     | 已复核   |
| LIST-6  | 首页、搜索与分类浏览 | lib/core/widgets/movie_grid_view.dart:83                                  | 缺 AlwaysScrollableScrollPhysics，短列表无法下拉刷新           | 低     | 待确认   |
| MOD-1   | 其余模块与可维护性   | lib/features/makers/screens/makers_screen.dart:82                         | 片商/导演/系列三份复制切片，Tab 长度双源                       | 中     | 已复核   |
| MOD-2   | 其余模块与可维护性   | lib/core/network/api_data.dart:107                                        | 实体归一化 4 份相同实现（复核：实为 5 份）                     | 低     | 已复核   |
| MOD-3   | 其余模块与可维护性   | lib/features/settings/screens/settings_screen.dart:6                      | settings 死代码 + STRUCTURE.md 漂移（同 ARCH-3）               | 低     | 已复核   |
| MOD-4   | 其余模块与可维护性   | lib/features/common/screens/common_list_screen.dart:124                   | 实体类别码裸字符串散落多模块                                   | 低     | 待确认   |
| MOD-5   | 其余模块与可维护性   | lib/features/actors/screens/actors_screen.dart:206                        | 演员路由裸串 5 处，无 location helper                          | 低     | 待确认   |
| MOD-6   | 其余模块与可维护性   | README.md:3                                                               | 版本 0.11.2 与实际 0.16.3 不符，测试数 850 与 1005 不符        | 低     | 待确认   |

## 五、建议修复顺序

### 立即修（P0）

1. **启动与线路自愈**：SEC-1/STATE-1（启动请求复用 DomainManager 的持久化线路与候选列表，或在 fallback
   失败后遍历候选）、SEC-2/ERR-3（把重试标记改为每请求作用域，并给 `rotate()`
   加互斥）。理由：主域被封是产品日常风险，当前会导致无法进入 App 且无自救入口，属可用性单点故障。
2. **永久性启动失败**：STATE-2/DATA-2/ERR-2/USER-3（两处 `jsonDecode` 与 `as Map` 包
   try/catch，失败删除坏键并按未登录继续启动）、DATA-1（热词/settings/user 容错解析或降级为空）。理由：改动小、后果不可恢复。
3. **明确用户可见功能错误**：USER-1（“我看过的”接入 `ProfileReviewMoviesScreen`/真实接口）、PLAY-1（seek
   分母改为进度条自身宽度）、ERR-1（统一解包 `DioException.error` 为 ApiException 并提供中文文案）。

### 本迭代（P1）

- 安全纵深：SEC-3（域名 scheme/host 校验）。
- 失败安全：STATE-3/USER-4（logout 先清内存后 best-effort 持久化、profile 退出加 try/catch）、STATE-4（
  `refreshListenable` + redirect 守卫 + 登出用 replace）。
- 播放器：PLAY-2（`_canAutoHide` 恢复时重启计时）、PLAY-3/PERF-2（剧照按槽位限高解码）。
- 列表：LIST-3（按满页推断 totalPages）、LIST-4（解析 ranking、末页判断收敛）、LIST-5（滚动监听加
  error/hasMore 守卫）。
- 错误体验：ERR-4（统一 `userFacingErrorMessage`）、ERR-5（演员详情错误态可重试）。
- 无障碍与布局：UIUX-2（表单可滚动）、UIUX-3（`onPrimary` + `selected` 语义）、UIUX-4（徽章配色与“第 N
  名”语义）、UIUX-5（响应减少动效/提供暂停）。
- 会话一致性：USER-2（Token 换号后 clear/sync 关注标签）。
- 架构：ARCH-1（FollowingTagsButton 上提 core）、ARCH-3/MOD-3（删除 settings 死代码并修正
  STRUCTURE.md）、MOD-1（抽取 core 泛型实体列表屏）。
- 测试：TEST-1（注册四个分支）、TEST-2（筛选/信息面板与控制器单测）、TEST-3（断言 imageUrl/width/height）。
- 基线：BASE-1（统一 Dart 版本后执行 `dart format`，纳入 CI）。

### 有余力（P2）

-
逐条处理其余低危发现：SEC-4/5/6、STATE-5/6、DATA-3/4/5、ARCH-2/4/5/6、TEST-4/5/6、PERF-1/3/4/5/6、ERR-6、UIUX-1/6、PLAY-4/5/6、USER-5/6、LIST-1/6、MOD-2/4/5/6。
- 待确认条目先做验证再决定：SEC-4（检查 debug 日志脱敏范围）、SEC-5/6（补错误契约与
  sendTimeout）、LIST-1（确认 search_magnet 是否处理 page）、LIST-2（确认服务端是否接受 `type=list`，复核认为
  cited evidence 自相矛盾）、UIUX-1（仅保留“我的清单”改名/删除这一有效缺口）、MOD-6（更新 README）。
- 文档收尾：统一 RULES.md 与 STRUCTURE.md 的路由位置与 settings 描述，补记
  auth_session_service.dart（STRUCTURE.md:74）。

## 六、未覆盖与说明

1. **执行边界**：本报告撰写阶段未运行任何命令；analyze/test/format/coverage
   的结果全部来自工作流给定的确定性基线，各维度审查员亦为只读审查。因此文中所有覆盖率百分比（含 TEST-1
   的 41%、TEST-2 的 0%/49%、TEST-5 的 73% 等）未经复核员重跑 coverage 验证，仅作辅助参考。
2. **未构建、未实测**：未执行 Android/iOS 构建；targetSdk ≥ 28 仅从 build.gradle.kts 继承
   `flutter.targetSdkVersion` 推断，“cleartext 默认关闭”未经构建验证；iOS 目录不存在，深链只涉及内部路由。
3. **未做网络/服务端实测**：LIST-3/LIST-4 依赖的 `total_pages`/`ranking` 服务端行为、LIST-1 的 `page`
   处理、LIST-2 的 `type=list` 接受度、SEC-3 的 TLS 绕过场景，均未联机验证。LIST-1 的“无限重复追加”与
   LIST-2 的“必然拿不到数据”依赖未证实前提，不能作为确定结论；LIST-2 的 cited evidence 被同一份
   openapi 的 `SearchNewEntity.lists` 推翻，建议先验证再关单。
4. **未做真机无障碍与性能实测**：UIUX 的对比度为 WCAG 公式计算或按色调推算，PERF 的内存量为量级推算（如
   1MB 图约 10MB 瞬时分配、1080p 剧照约 8MB/张），未经 profile 验证；TalkBack/VoiceOver 行为未在设备上复现。
5. **29 条待确认**：这些条目未进入复核预算，其中
   SEC-4/5/6、STATE-5/6、PERF-4/5/6、UIUX-1/6、PLAY-4/5/6、USER-5/6、LIST-1/2/6、MOD-4/5/6
   等为代码阅读结论，修复前建议先复核确认。
6. **复核修正已并入正文**：DATA-1 的失败 UI 是 StartupScreen 而非 StartupFailureScreen；ARCH-2
   不构成编译层依赖倒置（RULES.md 行号应为 :37）；MOD-2 实为 5 份重复且 series/search 副本有测试；UIUX-1
   有效范围缩小到“我的清单”改名/删除；PLAY-3 不会产生第二份全尺寸位图；PERF-2 “再次进入必然重复解码”表述偏强；MOD-1
   makers/directors 实际仅 3 行不同；TEST-5 “copyWith 丢字段”不成立但存在索引错位隐患。
7. **跨维度去重**：同一根因的条目已合并叙述并保留全部编号——SEC-1/STATE-1（启动固定域名）、SEC-2/ERR-3（
   `_retried` 粘滞）、STATE-2/DATA-2/ERR-2/USER-3（会话解码无兜底）、STATE-3/USER-4（logout
   失败安全）、PERF-2/PLAY-3（剧照原图解码）、ARCH-3/MOD-3（settings 死代码）。同一缺陷定级不同时（如 SEC-2
   高 / ERR-3 中），报告中两者都保留，修复优先级按较高者执行。
8. **计数口径**：共 72 条发现，高 6 / 中 28 / 低 38；已复核 43 条、待确认 29 条。该计数按 JSON 中各条目的
   `severity` 与 `status` 字段逐条统计，与分维度小计一致。

---
审查运行：dwfrun-02893896-3731-4ec5-81d1-4ccfd7abd0a1
