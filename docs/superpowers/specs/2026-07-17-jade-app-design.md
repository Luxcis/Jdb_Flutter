# Jade App Design Spec

> 日期：2026-07-17 ｜ 主题：Jade（JavDB 第三方客户端）全量应用设计 ｜ 状态：待审阅

本文件是 Jade 应用的单份详尽全量设计文档，覆盖总体架构、基础设施层、共享组件层、数据模型、底部导航壳与全局路由，以及需求中 0–10 节对应的全部页面设计。各页面给出组件拆分、数据流、接口映射、错误与空态、测试要点。文档末尾给出建议的实施路线图；实施阶段各自再走 spec → plan → 实施循环。

## 1. 概述与目标 / 范围边界

### 1.1 产品定位

Jade 是 JavDB 的第三方客户端（包名 `jade`，见 [pubspec.yaml](file:///../../pubspec.yaml)）。目标为实现官方客户端除**付费、在线观影、广告**之外的全部功能。API 与签名算法已完整逆向，见 [api-reference.md](file:///../../docs/api/api/api-reference.md) 与 [ALGORITHM.md](file:///../../docs/api/signature/ALGORITHM.md)。

### 1.2 范围边界

| 状态     | 模块                                                         | 对应 API                                                                                                                                        | 说明                |
| ------ | ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| ✅ 在范围内 | 认证注册、用户信息、影片内容、搜索、演员/导演/制作商/系列/编号、排行榜、评论、片单、标签、收藏、文章、启动初始化 | sessions、users、movies、search、actors、directors、makers、series、codes、rankings、reviews、lists、following\_tags、collected\_\*、articles、startup、about | 主体功能              |
| ✅ 在范围内 | 磁链下载                                                       | `GET /movies/{id}/magnets`                                                                                                                    | 仅展示磁链列表，不下载/不播放   |
| ❌ 不在范围 | 在线观影                                                       | `GET /movies/{id}/play`、`resume_play`                                                                                                         | 排除播放器与 M3U8       |
| ❌ 不在范围 | 会员支付                                                       | `/v3/plans`、`/v4/plans`、`payment_order`                                                                                                       | 排除套餐与下单           |
| ❌ 不在范围 | 钱包                                                         | `/wallets/*`                                                                                                                                  | 排除返利/提现           |
| ❌ 不在范围 | 广告                                                         | `/ads`、`/ads/splash_log`                                                                                                                      | 排除开屏与横幅           |
| ⚠️ 条件  | 播放记录上报                                                     | `GET /logs/movie_played`                                                                                                                      | 在线观影排除后此项无意义，暂不实现 |

> 署名假设：`movies/{id}/play` 相关的"可播放"筛选（通用页顶部单选）若服务端按影片字段返回，则在详情/列表展示该字段，但不实现播放动作。

## 2. 总体架构

### 2.1 分层与依赖规则

遵循 [RULES.md](file:///../../RULES.md) 的 Feature-First 约定（方案 A：Feature-First + 强共享组件层）。

* **公共层** **`lib/core/`**：网络、路由、存储、通用组件、常量、错误。被各 feature 依赖。

* **业务层** **`lib/features/<name>/`**：每 feature 内含 `screens/`、`widgets/`、`models/`、`services/`、`index.dart`。

* **依赖方向**：`feature → core` 单向；`feature ⇎ feature` 互不依赖；`core ⇎ feature` 不反向依赖。跨 feature 复用一律上提到 `core/`。

* **入口文件**：每 feature 的 `index.dart` 仅 export 路由需要的 Page 与公开模型，内部细节不外泄。

### 2.2 目录树

```
lib/
├── app.dart                          # MyApp：MaterialApp.router + Provider 注册 + 主题
├── main.dart                         # 启动：初始化 SP、StartupProvider、路由
├── core/
│   ├── network/
│   │   ├── api_client.dart           # Dio 单例 + 拦截器装配
│   │   ├── interceptors/
│   │   │   ├── signature_interceptor.dart   # jdsignature 注入
│   │   │   ├── auth_interceptor.dart         # Bearer Token 注入
│   │   │   ├── domain_switch_interceptor.dart # 608 域名热切换 + 重试
│   │   │   └── response_interceptor.dart     # 统一响应解包 + 错误归一
│   │   ├── signature.dart            # 签名算法（D1/D2 + MD5）
│   │   ├── domain_manager.dart       # 域名列表 + 状态机 + SP 持久化
│   │   ├── api_exception.dart        # ApiException(action, message)
│   │   └── endpoints.dart            # 路径常量
│   ├── router/
│   │   ├── app_router.dart           # GoRouter 配置 + ShellRoute
│   │   └── routes.dart               # 路径常量 + auth redirect
│   ├── storage/
│   │   └── storage_keys.dart         # SP 键常量 + 读写封装
│   ├── providers/
│   │   ├── theme_provider.dart       # (已存在)
│   │   ├── auth_provider.dart        # 登录态/用户/token
│   │   ├── startup_provider.dart     # 域名列表/线路
│   │   └── settings_provider.dart    # 默认筛选标签/线路选择/外观
│   ├── models/                       # 跨 feature 共享的基础模型
│   │   ├── movie.dart
│   │   ├── actor.dart
│   │   ├── paging.dart               # PagedResult<T>
│   │   └── ... (见 §5)
│   ├── widgets/                      # 强共享组件层（见 §4）
│   │   ├── movie_card.dart
│   │   ├── movie_grid_view.dart
│   │   ├── movie_list_tile.dart
│   │   ├── actor_card.dart
│   │   ├── actor_grid_view.dart
│   │   ├── section_header.dart
│   │   ├── filter_drawer.dart
│   │   ├── sort_segmented.dart
│   │   ├── sort_select.dart
│   │   ├── rating_badge.dart
│   │   ├── cached_image.dart
│   │   ├── empty_state.dart
│   │   ├── error_retry_widget.dart
│   │   └── pagination_controller.dart
│   ├── theme/
│   │   └── app_theme.dart            # (已存在)
│   └── constants/
│       └── app_constants.dart        # platform/channel/version 等
└── features/
    ├── home/                         # §7
    ├── rankings/                     # §8
    ├── categories/                   # §9
    ├── actors/                       # §10
    ├── profile/                      # §11
    ├── movie_detail/                 # §12
    ├── actor_detail/                 # §13
    ├── search/                       # §14
    ├── common/                       # §15 通用列表页
    ├── auth/                         # 登录/注册
    └── settings/                     # (已存在) 扩展
```

## 3. 基础设施层

### 3.1 dio 客户端与拦截器链

`ApiClient` 为单例，持有 `Dio` 实例，baseUrl 取自 `DomainManager.currentUrl`（启动时从 SP `key_baseurl` 读取，缺省 `https://jdforrepam.com`）。拦截器按序装配（请求方向由前到后，响应方向由后到前）：

1. **`SignatureInterceptor`**：为每个请求注入 `jdsignature` 头。格式 `{timestamp}.{d2}.{md5(timestamp + d1)}`，常量 `D1`/`D2` 取自 [ALGORITHM.md §4.5](file:///../../docs/api/signature/ALGORITHM.md)（已硬编码，无需 JNI）。同时注入 `accept-language: zh-CN`、`connection: keep-alive`。
2. **`AuthInterceptor`**：若 `AuthProvider.token` 非空，注入 `Authorization: Bearer {token}`。
3. **`ResponseInterceptor`**：解包统一响应 `{success, action, message, data}`。`success==1` 返回 `data`；`success==0` 抛 `ApiException(action, message)`。识别 `JWTVerificationError` → 清空登录态并触发路由重定向到 `/login`。
4. **`DomainSwitchInterceptor`**（错误拦截器 / `onError`）：当响应 HTTP 状态码为 `608` 或当前域名连续失败达阈值时，触发域名切换流程（见 §3.3）并用新 baseUrl 重试原请求（最多重试 1 次，避免死循环）。

### 3.2 签名算法 Dart 实现

`core/network/signature.dart` 直接实现，依赖 `crypto` 包的 MD5：

```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

class JdSignature {
  // 取自 ALGORITHM.md §4.5，已解密
  static const String _d1 =
      '71cf27bb3c0bcdf207b64abecddc970098c7421ee7203b9cdae54478478a199e7d5a6e1a57691123c1a931c057842fb73ba3b3c83bcd69c17ccf174081e3d8aa';
  static const String _d2 = 'lpw6vgqzsp';

  static String generate() {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final hash = md5.convert(utf8.encode('$ts$_d1'));
    return '$ts.$_d2.${hash.toString()}';
  }
}
```

> 依赖新增：`crypto`（MD5）、`dio`、`go_router`、`json_annotation`/`json_serializable`/`build_runner`（dev）、`cached_network_image`。

### 3.3 域名动态切换状态机

`DomainManager`（`ChangeNotifier`）持有 `List<String> apiDomains` 与当前索引。完整生命周期：

```
首次安装 → SP 无 key_baseurl → baseUrl = https://jdforrepam.com
  │
  ▼ 启动调用 GET /api/v1/startup?platform=android&app_channel=google&app_version=1.9.29&app_version_number=35
  │
  ▼ 取 data.backup_domains_data（Base64 加密串）
  │   解密（复用 ALGORITHM.md §4.3 的 getDecryptString 流程，密钥为证书 DER hex 前 5 字符 "30820"）
  │   得到 { apiDomains[], backupUrls[], unblockedAppDomain, permanentAppDomain, imageEndpoint }
  │
  ▼ 写入 apiDomains 到内存 + SP key_api_domains；主域名写入 key_baseurl
  │
  ▼ 正常请求 ── 成功 → 继续
  │
  │ 失败（608 / 连续失败）
  ▼ DomainSwitchInterceptor.onError → apiDomains 轮转取下一个 → 更新 key_baseurl → ApiClient 重建 Dio → 重试原请求
  │
  ▼ 若切换后域名 ≠ jdforrepam.com → 弹提示"切换到大陆可用域名"
  │
  ▼ 下次启动 → startup 接口刷新域名列表
```

要点：

* 域名切换在内存与 SP 双写，保证进程重启后仍可用。

* `ApiClient` 暴露 `swapBaseUrl(url)`，内部 `dio.options.baseUrl = url`（Dio 支持运行时改 baseUrl，无需重建实例）。

* CDN 图片域名 `https://tp.spfcas.com/rhe951l4q/` 固定写常量 `AppConstants.imageCdnBase`，影片封面/演员头像路径前缀拼此常量。

* `backup_domains_data` 解密失败时降级为纯 Base64 解码尝试；仍失败则回退主域名并记录日志。

### 3.4 go\_router ShellRoute 与底部导航壳

`MaterialApp.router`（见 [main.dart](file:///../../lib/main.dart) 改造）。`ShellRoute.builder` 渲染 `MainShell`（`NavigationBar` + `IndexedStack` 保活 5 Tab 状态），子路由为 5 个 Tab 根。详情页用顶层路由（覆盖 NavigationBar）。

### 3.5 Provider 清单

| Provider                         | 职责                            | 持久化键                         |
| -------------------------------- | ----------------------------- | ---------------------------- |
| `ThemeProvider`（已存在）             | 主题模式                          | `key_theme_mode`             |
| `AuthProvider`（`ChangeNotifier`） | token、用户对象、登录/登出、收藏计数         | `key_token`、`key_user`       |
| `StartupProvider`                | apiDomains、当前线路、imageEndpoint | `key_api_domains`、`key_line` |
| `SettingsProvider`               | 默认筛选标签、外观模式代理、线路选择            | `key_default_filter_tags`    |

### 3.6 shared\_preferences 键约定

| 键                         | 类型           | 说明                |
| ------------------------- | ------------ | ----------------- |
| `key_baseurl`             | String       | 当前 API 基域名        |
| `key_api_domains`         | String(JSON) | 备用域名列表            |
| `key_token`               | String       | JWT               |
| `key_user`                | String(JSON) | 用户对象缓存            |
| `key_theme_mode`          | String       | light/dark/system |
| `key_default_filter_tags` | String(JSON) | 默认筛选标签            |
| `key_search_history`      | String(JSON) | 搜索历史（≤20 条）       |
| `key_line`                | String       | 线路选择              |

### 3.7 错误处理与统一响应

* `ApiException`：`final String action; final String? message;`，覆盖 `ParameterInvalid`/`InvalidSignature`/`JWTVerificationError`/`NonExistentUser` 等。

* 全局 `ErrorBoundary`：网络错误 → `ErrorRetryWidget`；空数据 → `EmptyState`；业务错误 → `SnackBar`（繁体 message 原样展示或按 action 映射中文）。

* 登录失效（`JWTVerificationError`）→ `AuthProvider.logout()` → go\_router `redirect` 推到 `/login`。

### 3.8 测试策略

* **单元**：`signature_test.dart`（对照 [ALGORITHM.md §4.6](file:///../../docs/api/signature/ALGORITHM.md) 样例 `1784107027.lpw6vgqzsp.f48872e5a19ede4cb67fa509981eb0d1` 验证）、`DomainManager` 状态机轮转、各 service 用 `Dio` `MockAdapter`/fake。

* **Widget**：每页渲染 + 空/错态 + 交互。

* **集成**：启动→首页、登录→Top250、搜索→详情 等关键流。

* Mock 优先 fake `ApiClient`，注入 service 层。

## 4. 共享组件层（core/widgets）

契约式罗列，每个组件给出"做什么 / 怎么用 / 依赖"。

| 组件                                | 职责                                                                                                             | 关键 API                                           |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| `CachedImage`                     | `cached_network_image` 封装，自动拼 CDN 前缀、占位/错误图                                                                    | `CachedImage(url, {aspect})`                     |
| `MovieCard`                       | 影片卡：封面(3:4) + 标题 + 番号，点击→`/movie/:id`                                                                          | `MovieCard(movie: MovieSummary)`                 |
| `MovieGridView`                   | 3 列 `SliverGrid` + 分页 + 下拉刷新 + "换一组"；复用于首页 3×3、排行榜/类别/通用/我想看的等瀑布页                                              | `MovieGridView(controller:)`                     |
| `MovieListTile`                   | 三行布局（封面+截图 / 标题 / 番号·日期·备注）；复用于 Top250、我的关注                                                                    | `MovieListTile(movie:, rank:)`                   |
| `ActorCard`                       | 演员卡：圆头像 + 姓名，点击→`/actor/:id`                                                                                   | `ActorCard(actor:)`                              |
| `ActorGridView`                   | 3 列头像网格 + 分页                                                                                                   | `ActorGridView(controller:)`                     |
| `SectionHeader`                   | 标题（可加粗）+ 右侧动作（全部/往期推荐/换一组/筛选）                                                                                  | `SectionHeader(title:, trailing:)`               |
| `FilterDrawer`                    | `endDrawer` 抽屉，按传入 `FilterSchema` 动态渲染选项，确认后回传 `Map`                                                           | `FilterDrawer(schema:, onChanged:)`              |
| `SortSegmented`                   | 按钮样式单选组（日/周/月榜等）                                                                                               | `SortSegmented(options:, value:, onChanged:)`    |
| `SortSelect`                      | 排序下拉                                                                                                           | `SortSelect(options:, value:, onChanged:)`       |
| `RatingBadge`                     | 排名角标：#1 金、#2 银、#3 铜、其余灰                                                                                        | `RatingBadge(rank:)`                             |
| `TagChip`                         | 标签芯片                                                                                                           | `TagChip(label:, selected:)`                     |
| `EmptyState` / `ErrorRetryWidget` | 空/错态 + 重试回调                                                                                                    | —                                                |
| `PaginationController<T>`         | `ChangeNotifier`，管 `page/limit/hasMore/isLoading/items`，`fetchMore()` 调 service；`refresh()`；`reshuffle()`（换一组） | `PaginationController(fetch: (page) => Future>)` |

## 5. 数据模型总览

全部 `@JsonSerializable(fieldRename: FieldRename.snake)`（遵循 [CLAUDE.md](file:///../../CLAUDE.md)）。字段以 [api-reference.md](file:///../../docs/api/api/api-reference.md) 与 `jdb_api_openapi.json` 为准，以下列核心模型。

| 模型                                 | 关键字段                                                                                                                                       | 来源接口                                      |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------- |
| `MovieSummary`                     | id, number, title, coverUrl, releaseDate, duration, score                                                                                  | latest/recommend/top/tags/rankings/search |
| `MovieDetail`                      | 继承 Summary + director, maker, series, actors\[], screenshots\[], tags\[], magnetCount, wantWatchCount, watchedCount, playable, hasSubtitle | `GET /movies/{id}` (v4)                   |
| `Magnet`                           | hash, title, size, publishDate, isHighDefinition                                                                                           | `GET /movies/{id}/magnets`                |
| `Review`                           | id, score, content, status, author{name}, likedCount, createdAt                                                                            | `GET /movies/{id}/reviews`                |
| `ActorSummary`                     | id, name, avatarUrl                                                                                                                        | actors/recommend/rankings/actors          |
| `ActorDetail`                      | 继承 + birthday, age, height, cup, bust, waist, hip, birthplace, movieCount                                                                  | `GET /actors/{id}`                        |
| `Director` / `Maker` / `Publisher` | id, name, avatarUrl, movieCount                                                                                                            | directors/makers/publishers               |
| `Series`                           | id, name, movieCount                                                                                                                       | series                                    |
| `Code`                             | id, number, movieCount                                                                                                                     | codes                                     |
| `ListModel`                        | id, name, movieCount, viewedCount                                                                                                          | lists                                     |
| `Tag`                              | id, name, value                                                                                                                            | `GET /v2/tags`                            |
| `Article`                          | id, title, coverUrl, publishDate                                                                                                           | articles                                  |
| `RankingEntry`                     | 复用 `MovieSummary` + rank                                                                                                                   | rankings                                  |
| `PagedResult<T>`                   | items\[], currentPage, totalPages, total                                                                                                   | 通用分页包装                                    |
| `StartupData`                      | backupDomainsData, settings, user                                                                                                          | `GET /startup`                            |
| `BackupDomains`                    | apiDomains\[], backupUrls\[], unblockedAppDomain, permanentAppDomain, imageEndpoint                                                        | 由 backupDomainsData 解密                    |

> 生成命令：`dart run build_runner build --delete-conflicting-outputs`。

## 6. 底部导航壳与全局路由表

`ShellRoute` 承载 5 Tab，详情/编辑页为顶层路由覆盖展示。

| 路径                                                                                         | 页面    | 鉴权  | 说明                            |
| ------------------------------------------------------------------------------------------ | ----- | --- | ----------------------------- |
| `/home`                                                                                    | 首页    | 否   | §7                            |
| `/rankings`                                                                                | 排行榜   | 否   | §8（Top250 内部需登录）              |
| `/categories`                                                                              | 类别    | 否   | §9                            |
| `/actors`                                                                                  | 演员    | 否   | §10（推荐 Tab 需登录）               |
| `/profile`                                                                                 | 我的    | 否   | §11（子页多数需登录）                  |
| `/movie/:id`                                                                               | 影片详情  | 否   | §12                           |
| `/actor/:id`                                                                               | 演员详情  | 否   | §13                           |
| `/search`                                                                                  | 搜索页   | 否   | §14                           |
| `/search/image`                                                                            | 图片搜索  | 否   | 识演员/识影片                       |
| `/login`、`/register`                                                                       | 登录/注册 | 否   | auth                          |
| `/series/:id`、`/maker/:id`、`/director/:id`、`/code/:id`                                     | 实体详情  | 否   | 复用 §15 通用列表                   |
| `/list/:id`                                                                                | 片单详情  | 否   | lists                         |
| `/profile/want-watch`、`/watched`、`/following`、`/recent`                                    | 我的子列表 | 是   | §11（`redirect` 登录拦截）          |
| `/profile/favorites`                                                                       | 收藏总入口 | 是   | §11（含子页）                      |
| `/profile/lists`、`/profile/info`、`/profile/settings`                                       | 我的子页  | 是/否 | §11                           |
| `/common`                                                                                  | 通用列表页 | 否   | §15（带 query：type/sort/filter） |
| `/settings/appearance`、`/settings/line`、`/settings/default-filter`、`/settings/clear-cache` | 设置子页  | 否   | §11                           |

`redirect` 逻辑：目标在"需登录"集合且 `AuthProvider.token == null` → 重定向 `/login?from={原路径}`，登录成功后回跳。

***

## 7. 首页（feature: home）

**接口**：`GET /movies/recommend?period=`、`GET /movies/recommend_periods`、`GET /movies/latest?type=&page=&limit=`、`GET /movies/tags`（近期磁链更新，见假设）。

**布局**（自上而下，`CustomScrollView` + slivers）：

1. **顶部豆腐块横滚条**：横向 `ListView`，`Wrap`-free，每项为 `Card`+图标+文字。项与跳转：

   * 看热播 → `/rankings` 并切到"看热播" Tab

   * AV资讯 → `/articles`（文章列表，`GET /articles`）

   * 看短评 → `/reviews/hotly`（热门评论，`GET /reviews/hotly?period=`）

   * 找磁链 → `/search/magnet`（`GET /search_magnet?q=`）

   * 识演员 → `/search/image?type=actor`

   * 识影片 → `/search/image?type=movie`

   * 系列 → `/series`（系列列表，`GET /series`）

   * 片商 → `/makers`（制作商列表，`GET /makers`）

   * 导演 → `/directors`（导演列表，`GET /directors`）
2. **佳片推荐**：`SectionHeader(title: '佳片推荐', trailing: '往期推荐' → /movies/recommend?period=历史)` + 轮播 `PageView`（封面+标题，点击→`/movie/:id`）。periods 由 `recommend_periods` 提供，默认取最新。
3. **最新上架**：`SectionHeader(title: '最新上架', trailing: '全部' → /common?type=latest)` + 3×3 `MovieGridView`（无分页，仅首屏 9 条 + "换一组"调 `reshuffle`）。
4. **近期磁链更新**：`SectionHeader(title: '近期磁链更新', trailing: '全部' → /common?type=magnet)` + 3×3 `MovieGridView` + "换一组"。

> 假设标注：`/movies/latest` 仅有 `type` 参数；"近期磁链更新"映射为 `GET /movies/latest?type={磁链类型}`，若服务端无对应 type 则改用 `GET /movies/tags` 含磁链筛选，待接口联调时确认，spec 自审见 §17。

**状态**：`HomeProvider`（`ChangeNotifier`）持有推荐轮播/最新/磁链三组数据，首屏并发请求。**错误/空**：各 Section 独立 `ErrorRetryWidget`。

## 8. 排行榜（feature: rankings）

**接口**：`GET /movies/top?type=&year=&page=&limit=`（Top250，鉴权）、`GET /rankings/playback?period=`（看热播）、`GET /rankings?type=&period=`（有码/无码/欧美/FC2）、`GET /rankings/actors?type=&period=`（演员月榜）。

顶部 `TabBar`：Top250、看热播、有码、无码、欧美、FC2（与底部导航共享 `DefaultTabController` 或自管）。

### 8.1 Top250（需登录）

* 顶部筛选按钮 → 弹 `FilterDrawer`（年份、类型）。

* 竖向 `ListView.builder` 瀑布式，每项 `MovieListTile`：第一行 `CachedImage(封面)+截图横向小图`，封面左上角 `RatingBadge(rank:)`（#1 金/#2 银/#3 铜/余灰）；第二行标题；第三行 番号·日期·备注。

* 未登录：本 Tab 渲染登录引导卡（按钮→`/login?from=/rankings?tab=top`）。

### 8.2 看热播

* 顶部两组 `SortSegmented`：① 高评价（默认）/全部；② 日榜（默认）/周榜/月榜。

* `MovieGridView` 瀑布式（封面+标题+番号）。

### 8.3 有码 / 无码 / 欧美

* 顶部一组 `SortSegmented`：日榜（默认）/周榜/月榜/演员月榜。

* `MovieGridView` 瀑布式。type 映射：有码/无码/欧美/FC2。

### 8.4 FC2

* 顶部一组 `SortSegmented`：日榜/周榜/月榜（无演员月榜）。

* `MovieGridView` 瀑布式。

**状态**：每 Tab 一个 `PaginationController<MovieSummary>`，切 Tab/切单选时 `refresh()`。**错误**：单 Tab 错误不影响其他。

## 9. 类别（feature: categories）

**接口**：`GET /movies/tags?type=&sort_by=&order_by=&page=&limit=`、`GET /v2/tags?type=&page=&limit=`（筛选项来源）。

* 第一排 `TabBar`：有码、无码、欧美、FC2、动漫。type 映射。

* 第二排：左侧排序按钮（点击弹 `SortSelect`/底部 sheet 列出排序项），右侧筛选按钮（弹 `FilterDrawer`）。**不同 Tab 排序与筛选项不同**——以 `CategoryConfig` 表驱动：

| Tab | 排序选项     | 筛选项                |
| --- | -------- | ------------------ |
| 有码  | 最新/热门/评分 | 标签、演员、片商、系列、发行日期区间 |
| 无码  | 同上       | 同上                 |
| 欧美  | 同上       | 同上                 |
| FC2 | 同上       | 标签、发行日期区间          |
| 动漫  | 同上       | 标签、系列              |

* `MovieGridView` 瀑布式（封面+标题+番号）。

**状态**：`CategoriesProvider` 持当前 Tab、sort、filter、`PaginationController`。**复用**：`FilterDrawer` 按 `CategoryConfig.filterSchema` 渲染。

## 10. 演员（feature: actors）

**接口**：`GET /actors/recommend`（推荐三段）、`GET /actors?type=&page=&limit=`（分类列表）、`GET /rankings/actors?type=&period=`。

顶部 `TabBar`：推荐（需登录）、有码(女)、有码(男)、无码、欧美(女)、欧美(男)。

### 10.1 推荐（不需瀑布加载，但需登录）

三段 `SectionHeader`：

1. 新人（加粗）— 更新日期：3×3 `ActorGridView`（首屏 9，无分页）。
2. 月排名 右侧"全部" → `/actors?type=ranking&period=monthly`：3×3 `ActorGridView`。
3. Fanza(DMM)推荐（加粗）— 更新日期：`ActorGridView`（数量按接口）。

### 10.2 有码(女) / 有码(男) / 无码 / 欧美(女) / 欧美(男)

* 顶部筛选按钮 → `FilterDrawer`（性别、标签、首字母等，按 type 配置）。

* `ActorGridView` 瀑布式（头像+姓名）。

**状态**：推荐 Tab 用 `ActorRecommendProvider`；分类 Tab 各用 `PaginationController<ActorSummary>`。未登录访问推荐 → 登录引导卡。

## 11. 我的（feature: profile）

**接口**：`GET /users`、`GET /users/additional`、`GET /users/collected_actors/_codes/_directors/_lists/_makers/_series`、`GET /users/recent_viewed`、`GET /lists`、`GET /v2/users/review_movies`、`POST /users/change_password`、`POST /users/change_username`。

### 11.1 未登录态

* 顶部大登录按钮 → `/login`。

* `Cell` 列表：我想看的、我看过的、我的关注、我的收藏、我的清单、近期浏览、个人资料、设置。点击任意需登录项 → `redirect /login?from=...`；设置项可直接进入。

### 11.2 已登录态

`Cell` 项及小标题（X 部影片等计数取自 `/users` 返回的 `want_watch_count`/`watched_count` 等）：

* **我想看的**（瀑布）→ `/profile/want-watch`：顶部 Tab 全部/有码/无码/欧美/FC2/动漫 + 右侧筛选按钮；`MovieGridView`；接口 `GET /v2/users/review_movies?status=want`。

* **我看过的**（瀑布）→ `/profile/watched`：同上 Tab + 筛选；`GET /v2/users/review_movies?status=watched`。

* **我的关注**（瀑布）→ `/profile/following`：顶部 Tab 关注列表；`MovieListTile` 三行布局；接口关注标签影片流（`following_tags` 相关）。

* **我的收藏** → `/profile/favorites`：Cell 列表 → 子页：

  * 收藏的演员：Tab 全部/有码/无码/欧美；`ActorGridView`；`GET /users/collected_actors`。

  * 收藏的片商：Cell 片商列表 → `/maker/:id`；`GET /users/collected_makers`。

  * 收藏的系列：Cell → `/series/:id`；`GET /users/collected_series`。

  * 收藏的导演：Cell → `/director/:id`；`GET /users/collected_directors`。

  * 收藏的番号：Cell → `/code/:id`；`GET /users/collected_codes`。

  * 收藏的清单：Cell（小标题 X 部影片, 被查看 X 次）→ `/list/:id`；`GET /users/collected_lists`。

* **我的清单** → `/profile/lists`：Cell（X 部影片）→ `/list/:id`；`GET /lists`。

* **近期浏览** → `/profile/recent`：`MovieGridView`；`GET /users/recent_viewed`。

* **个人资料** → `/profile/info`：Cell 电子邮箱、短评被举报次数、短评被删次数、禁言次数（小标题：超最大次数封号）、待审核/已通过订正数（小标题：订正来自网页版影片详情）、修改密码、修改用户名。字段取 `/users/additional`。

> 假设标注："订正功能来自网页版影片详情"——App 内暂不发起订正，仅在个人资料展示计数字段。

### 11.3 设置 → `/profile/settings`

Cell：外观模式、线路选择、默认筛选标签、清除缓存。

* 外观模式 → `/settings/appearance`（复用/扩展已存在的 [settings\_screen.dart](file:///../../lib/features/settings/screens/settings_screen.dart)）。

* 线路选择 → `/settings/line`：列出 apiDomains，切换写 `key_baseurl` 并通知 `StartupProvider`。

* 默认筛选标签 → `/settings/default-filter`：选默认 type/sort 写 `key_default_filter_tags`。

* 清除缓存 → 清 `cached_network_image` 缓存 + 确认弹窗。

## 12. 影片详情（feature: movie\_detail）

**接口**：`GET /movies/{id}` (v4)、`GET /movies/{id}/magnets`、`GET /movies/{id}/reviews`、`GET /movies/may_also_like`、`GET /lists/related`、`POST /movies/{id}/reviews`、`POST /lists/{id}/movie_actions`。

**布局**（`CustomScrollView`，底部悬浮抽屉）：

1. 顶部标题（加粗，超长省略 `TextOverflow.ellipsis`）。
2. 影片封面（大图）。
3. 影片信息卡：番号、发行日期、时长、导演、片商、系列、评分；按钮组（想看/看过/存入清单，调 `/v2/users/review_movies` 或 listActions）；"X 人想看，X 人看过"。
4. 类别：`TagChip` 横滚。
5. 演员：横向 `ActorCard` 列表，点击→`/actor/:id`。
6. 剧照：横向 `CachedImage`。
7. TA还出演过：演员的其他作品 `MovieGridView`（横向）。
8. 你可能也喜欢：`MovieGridView`（横向）。
9. **底部悬浮抽屉**（`DraggableScrollableSheet` 或固定底部 `NavigationBar` 上方）：顶部 Tab 切换 磁链下载 / 短评 / 相关清单：

   * 磁链下载：`Magnet` 列表（hash、大小、日期、HD 标），点击复制磁链（不下载）。

   * 短评：`Review` 列表 + 撰写入口（`POST /movies/{id}/reviews`：score/content/status）。

   * 相关清单：`ListModel` 列表 → `/list/:id`。

**状态**：`MovieDetailProvider`。**错误**：详情失败全屏 `ErrorRetryWidget`；子模块各自降级。

## 13. 演员详情（feature: actor\_detail）

**接口**：`GET /actors/{id}?sort_by=&order_by=&page=&limit=`、`POST /actors/{id}/collect_actions`（收藏）。

* 演员头像（大圆/方）。

* 演员姓名。

* "出演过 X 部影片"。

* 更多信息按钮 → `FilterDrawer`/`showModalBottomSheet` 展示：姓名、出演过 X 部、生日、年龄、身高、罩杯、胸围、腰围、臀围、出生地。

* 作品 `MovieGridView` 瀑布式（封面+标题+番号）；顶部可挂 `SortSelect`（sort\_by/order\_by）。

* 收藏按钮调 `collect_actions`。

## 14. 搜索（feature: search）

**接口**：`GET /v2/search?q=&type=&code=`、`GET /search_magnet?q=`、`GET /search_image`。

### 14.1 搜索页

* 搜索框（`TextField`，提交→结果页）。

* 近期热搜（接口或本地？见假设，暂本地 `key_search_history` + 可选服务端热门词）。

* 历史搜索（本地 `key_search_history`，可删）。

### 14.2 搜索结果页

顶部 `TabBar`：影片、演员、系列、片商、导演、清单、番号。

* **影片**：顶部固定筛选条件（复用 §15 的 全部/可播放/含磁链/字幕 + 排序）；`MovieGridView` 瀑布；`GET /v2/search?q=&type=movie`。

* **演员**：`ActorGridView` 瀑布；`type=actor`。

* **系列**：Cell 列表（数字=影片数）；`type=series`。

* **片商**：Cell 列表（数字）；`type=maker`。

* **导演**：Cell 列表（数字）；`type=director`。

* **清单**：Cell 列表（小标题 X 部影片）；`type=list`。

* **番号**：Cell 列表（数字）；`type=code`。

> 假设标注：搜索 `type` 取值待联调；若服务端不支持按 type 拆分，则前端用 `code` 参数或本地过滤兜底。

## 15. 通用列表页（feature: common）

**接口**：`GET /movies/tags?type=&sort_by=&order_by=&page=&limit=`、各实体详情的影片列表（`/series/{id}`、`/makers/{id}`、`/directors/{id}`、`/codes/{id}`、`/lists/{id}`）。

* 导航栏：标题（由来源决定）。

* 顶部左侧 `SortSegmented`：全部 / 可播放 / 含磁链（默认）/ 字幕。

* 右侧 `SortSelect`：排序（最新/热门/评分…）。

* `MovieGridView` 瀑布式（封面+标题+番号）。

**复用场景**：首页"全部"入口、类别"全部"、系列/片商/导演/番号/片单详情页的影片列表、搜索结果影片 Tab、个人中心列表子页。

**参数化**：`CommonListPage(config: CommonListConfig(title, dataSource, fixedFilter, sortOptions))`，`dataSource` 为 `(page, filter, sort) => Future<PagedResult<MovieSummary>>`。

## 16. 实施路线图

虽为单份设计，建议分阶段落地（每阶段各自 spec → plan → 实施）：

1. **阶段 0 基础设施**：dio + 三拦截器 + 签名 + `DomainManager` 状态机 + go\_router ShellRoute + Provider 注册 + SP 键 + 主题（改 [main.dart](file:///../../lib/main.dart)/[app.dart](file:///../../lib/app.dart)）。
2. **阶段 1 数据模型 + 共享组件**：§5 全部模型 + `dart run build_runner`；§4 组件。
3. **阶段 2 底导壳 + 首页**：5 Tab 骨架 + §7。
4. **阶段 3 排行榜 + 类别**：§8、§9（复用 grid/drawer）。
5. **阶段 4 演员 + 演员详情**：§10、§13。
6. **阶段 5 影片详情**：§12 + 底部抽屉三 Tab。
7. **阶段 6 搜索 + 通用页**：§14、§15。
8. **阶段 7 我的 + 收藏子页 + 个人资料 + 设置**：§11。
9. **阶段 8 登录/注册 + auth gating**：auth feature + `redirect`。

## 17. Spec 自审（占位/矛盾/歧义/范围）

* **占位扫描**：无 TBD/TODO；`crypto`/`dio`/`go_router` 等依赖需在实施时 `flutter pub add`，spec 已列。

* **内部一致性**：§3.4 ShellRoute 与 §6 路由表一致；§4 组件被 §7–§15 复用关系一致；排除项（§1.2）与各页接口映射一致（无 play/wallet/payment/ads 调用）。

* **范围**：聚焦单一 App，体量大但内聚，单份设计可支撑后续分阶段 plan。

* **歧义**（已显式标注假设，待联调/审稿定夺）：

  1. "近期磁链更新"接口映射（§7）——`/movies/latest?type=` 还是 `/movies/tags` 含磁链筛选。
  2. "订正功能"仅展示计数字段，App 不发起订正（§11.2）。
  3. 搜索 `type` 取值与拆分方式（§14.2）。
  4. "近期热搜"数据来源：本地历史 vs 服务端热门词（§14.1）。
  5. `backup_domains_data` 解密方式复用 `getDecryptString`，失败降级（§3.3）。
  6. "可播放"筛选在排除在线观影后仅作字段展示（§1.2/§15）。

