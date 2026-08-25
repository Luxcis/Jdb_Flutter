# 项目结构说明

本文件描述 Jade（`Jdb_Flutter`）的目录组织、公共层内容与新增 feature 的约定，与 `RULES.md` 的「项目结构（Feature-First）」一节对应。

## 1. 总览

项目采用 **Feature-First** 结构：公共能力集中放在 `lib/core/`，具体业务按模块拆分在 `lib/features/`，每个 feature 内部再按职责划分 `screens/`、`widgets/`、`models/`、`services/` 等子目录。

依赖方向固定为 `feature → core` 单向，feature 之间互不依赖，`core` 不反向依赖任何 feature。跨 feature 复用的能力一律上提到 `lib/core/`。

```
lib/
├── main.dart                 # 应用启动：初始化 Provider、注入依赖、构建路由
├── app.dart                  # MyApp：MaterialApp.router + Provider 注册 + 主题
├── core/                     # 公共层，被各 feature 依赖
│   ├── constants/            # 全局常量
│   ├── device/               # 设备信息相关
│   ├── models/               # 跨 feature 共享的数据模型（含生成的 .g.dart）
│   ├── network/              # 网络请求、API 客户端、拦截器、签名、域名管理
│   ├── providers/            # 全局状态管理（主题/登录/设置/启动等）
│   ├── router/               # 路由配置与路径常量
│   ├── services/             # 跨 feature 公共服务
│   ├── storage/              # 本地存储键常量与读写封装
│   ├── theme/                # 应用主题
│   ├── utils/                # 纯工具函数
│   └── widgets/              # 可复用通用组件
└── features/                 # 业务模块
    ├── <feature_name>/
    │   ├── screens/          # 页面
    │   ├── widgets/          # 模块内私有组件
    │   ├── models/           # 数据模型
    │   ├── services/         # 业务逻辑、API 调用
    │   └── index.dart        # 对外入口，仅 export 路由需要的 Page 和公开模型
    └── ...
```

## 2. 公共层 `lib/core/`

| 目录 | 职责 | 主要内容 |
|------|------|---------|
| `constants/` | 全局常量 | `app_constants.dart`（兜底域名、图片 CDN、版本等） |
| `device/` | 设备信息 | `login_device_info_service.dart`（登录设备参数） |
| `models/` | 跨 feature 共享模型 | 影片、演员、导演、片商、系列、番号、磁链、评论、标签、排行榜、分页、启动数据等（`*.g.dart` 为 `build_runner` 生成） |
| `network/` | 网络层 | `api_client.dart`（Dio 单例）、拦截器（签名/Auth/域名切换/响应/日志）、`domain_manager.dart`（域名轮转状态机）、`signature.dart`（签名算法）、`endpoints.dart`（路径常量）、`api_exception.dart`（统一异常）、`review_api.dart`、`startup_api_client.dart`、`backup_domains_decryptor.dart`、`image_decryptor.dart`、`cache_service.dart`、`testing/fake_adapter.dart` |
| `providers/` | 全局状态 | `ThemeProvider`、`AuthProvider`、`SettingsProvider`、`StartupProvider` |
| `router/` | 路由 | `app_router.dart`（GoRouter 配置）、`routes.dart`（路径常量） |
| `services/` | 公共服务 | `session_refresh_service.dart`（会话刷新） |
| `storage/` | 本地存储 | `storage_keys.dart`（SP 键常量）、`login_credential_store.dart` |
| `theme/` | 主题 | `app_theme.dart`（Material 3、`ColorScheme.fromSeed`） |
| `utils/` | 工具函数 | `github_proxy.dart`（GitHub 代理拼接）、`time_format.dart` |
| `widgets/` | 通用组件 | 影片卡、演员卡、封面图、评分角标、分页列表、筛选抽屉、排序控件、空/错态、磁链项、短评卡、图片画廊等 |

## 3. 业务模块 `lib/features/`

项目现有 17 个 feature，均遵循统一的 `screens/`、`widgets/`、`models/`、`services/` 子目录约定（并不是每个 feature 都用到全部子目录，按需创建）。

| Feature | 职责 | 主要子目录 |
|---------|------|-----------|
| `home` | 首页：豆腐块入口、佳片推荐轮播、最新上架、近期磁链更新 | `models/` `providers/` `screens/` `services/` `widgets/` |
| `rankings` | 排行榜：Top250、看热播、有码、无码、欧美、FC2 | `screens/` `services/` |
| `categories` | 类别：有码、无码、欧美、FC2、动漫，含排序与筛选 | `models/` `screens/` `services/` `widgets/` |
| `actors` | 演员列表：推荐、有码/无码/欧美分类、筛选、演员详情 | `models/` `screens/` `services/` `widgets/` |
| `actor_detail` | 演员详情（归入 `actors` feature 的 `screens/`） | — |
| `movie_detail` | 影片详情：磁链、短评、相关清单抽屉；预告片/剧照；预览播放 | `models/` `screens/` `services/` `widgets/` |
| `search` | 搜索：影片/演员/实体、磁链搜索、历史/热门词 | `models/` `screens/` `services/` `widgets/` |
| `common` | 通用影片列表页（按标题/类型/分类参数化复用） | `screens/` `services/` |
| `articles` | 文章：新闻/资讯列表与详情（HTML 渲染） | `models/` `screens/` `services/` `widgets/` |
| `reviews` | 热门短评页 | `models/` `screens/` `services/` |
| `series` | 系列列表 | `models/` `screens/` `services/` |
| `makers` | 片商列表 | `screens/` `services/` |
| `directors` | 导演列表 | `screens/` `services/` |
| `profile` | 我的：用户信息、想看/看过、关注、收藏、清单、近期浏览、设置、更新、Token 认证 | `screens/` `services/` `widgets/` |
| `following` | 关注标签：关注影片流、关注页 | `models/` `screens/` `services/` `widgets/` |
| `auth` | 登录、注册 | `screens/` |
| `settings` | 设置：外观、线路、默认筛选标签、清除缓存 | `screens/` `widgets/` |
| `startup` | 启动页：域名引导、会话刷新、关注同步 | `screens/` |

> 说明：`actor_detail` 的页面与数据逻辑在 `actors` feature 的 `screens/actor_detail_screen.dart` 与 `services/actor_service.dart` 中实现，未单独拆出 feature。

## 4. 新增 feature 的约定

新增一个业务模块时，按以下结构创建目录：

```
lib/features/<feature_name>/
├── screens/          # 页面（路由需要的 Page）
├── widgets/          # 模块内私有组件（如需）
├── models/           # 数据模型（如需）
├── services/         # 业务逻辑、API 调用（如需）
└── index.dart        # 对外入口（必须）
```

### 命名约定

- 目录名统一使用小写 `snake_case`，例如 `movie_detail`、`search`。
- 文件名统一使用小写 `snake_case`，例如 `movie_detail_screen.dart`、`actor_service.dart`。
- 类名使用 `PascalCase`，业务页面以 `Page` 或 `Screen` 结尾，例如 `HomePage`、`MovieDetailPage`。

### 结构规则

1. **统一子目录**：feature 下允许 `screens/`、`widgets/`、`models/`、`services/`，新增时只在这几类目录中加，不随意在 feature 根目录创建新目录名。
2. **入口文件**：每个 feature 必须有 `index.dart`，对外只 export 路由需要的 Page 与公开模型，内部实现细节不暴露。
3. **依赖方向**：feature 只依赖 `lib/core/`，feature 之间不互相依赖；`core` 不依赖具体 feature。跨 feature 复用必须上提到 `core/`。
4. **路由接入**：新增页面需要在 `lib/core/router/app_router.dart` 注册路由，并在 `lib/core/router/routes.dart` 添加路径常量。

## 5. 相关文档

- `RULES.md`：项目级约定（结构、主题、发布流程）。
- `docs/main/jdb-product-spec.md`：产品需求规范。
- `docs/main/`：API 逆向工程文档、安全签名/域名/图片处理说明。
- `docs/superpowers/`：各功能的设计（`specs/`）与实现（`plans/`）文档。
