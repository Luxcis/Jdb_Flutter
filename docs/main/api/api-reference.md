# API Reference

> 日期：2026-07-21  
> 数据源：`jdb_api_openapi.json`、逆向安全文档、当前 Flutter 网络层实现

## 1. Base URL 与动态切换

| 类型 | URL | 说明 |
| --- | --- | --- |
| 主域名/默认启动域名 | `https://jdforrepam.com` | 首次安装、本地无 `key_baseurl` 时使用；startup 成功后继续优先写入 |
| 图片 CDN | `https://tp.spfcas.com/rhe951l4q/` | 封面、头像、截图等资源前缀 |

### 1.1 启动初始化

应用启动时请求：

```http
GET /api/v1/startup?platform=android&app_channel=google&app_version=1.9.29&app_version_number=35
```

响应中的 `backup_domains_data` 为 Base64 加密数据，解密后包含：

| 字段 | 说明 |
| --- | --- |
| `apiDomains` | 可用 API 域名列表，按优先级排列 |
| `backupUrls` | 备用 URL 列表 |
| `unblockedAppDomain` | 当前未封锁域名 |
| `permanentAppDomain` | 永久官网域名 |
| `imageEndpoint` | 图片服务端点 |

当前实现位置：

- `lib/core/network/backup_domains_decryptor.dart`
- `lib/core/network/domain_manager.dart`
- `lib/core/providers/startup_provider.dart`
- `lib/core/network/interceptors/domain_switch_interceptor.dart`

### 1.2 切换状态机

```text
首次安装
  -> 读取 key_baseurl，缺省 jdforrepam.com
  -> 请求 /api/v1/startup
  -> 解密 backup_domains_data 得到 apiDomains
  -> 写入 key_api_domains 与 key_baseurl
  -> 正常请求
  -> 遇到 HTTP 608 或连续失败
  -> DomainManager 轮转到下一个 apiDomain
  -> 更新 Dio baseUrl 与本地 key_baseurl
  -> 原请求最多重试 1 次
```

切换后若当前域名不是 `jdforrepam.com`，界面层可以提示 `切换到大陆可用域名`。

### 1.3 本地存储键

| Key | 类型 | 说明 |
| --- | --- | --- |
| `key_baseurl` | String | 当前 API 域名 |
| `key_api_domains` | String(JSON) | 可轮转 API 域名列表 |
| `key_line` | String | 用户选择线路 |
| `key_token` | String | Bearer token |
| `key_user` | String(JSON) | 用户信息 |
| `key_theme_mode` | String | 外观模式 |
| `key_default_filter_tags` | String(JSON) | 默认筛选标签 |
| `key_search_history` | String(JSON) | 搜索历史 |

## 2. 认证与请求头

所有请求注入 `jdsignature`：

```text
jdsignature: {timestamp}.lpw6vgqzsp.{md5(timestamp + d1)}
```

登录后需要认证的接口额外注入：

```text
Authorization: Bearer {token}
```

基础请求头：

| Header | 说明 |
| --- | --- |
| `jdsignature` | 动态签名，所有请求必带 |
| `Authorization` | 登录接口返回 token 后注入 |
| `accept-language` | 固定 `zh-CN` |
| `connection` | 固定 `keep-alive` |

## 3. 统一响应

```json
{
  "success": 1,
  "action": null,
  "message": null,
  "data": {}
}
```

- `success == 1`：`ResponseInterceptor` 返回 `data`。
- `success == 0`：抛出 `ApiException(action, message)`。
- `JWTVerificationError`：清空登录态并跳转登录。

## 4. 接口分组

| 分组 | 关键路径 | 页面 |
| --- | --- | --- |
| Startup | `/api/v1/startup`、`/api/v1/about` | 启动、设置线路 |
| Auth | `/api/v1/sessions`、`/api/v1/users` | 登录、注册 |
| Movies | `/api/v1/movies/latest`、`/api/v1/movies/recommend`、`/api/v4/movies/{id}` | 首页、详情 |
| Rankings | `/api/v1/rankings`、`/api/v1/rankings/playback`、`/api/v1/rankings/actors` | 排行榜 |
| Tags/Categories | `/api/v1/movies/tags`、`/api/v2/tags` | 类别、筛选 |
| Actors | `/api/v1/actors`、`/api/v1/actors/recommend`、`/api/v1/actors/{id}` | 演员、演员详情 |
| Search | `/api/v2/search`、`/api/v2/search_image`、`/api/v1/search_magnet` | 搜索 |
| User | `/api/v1/users`、`/api/v1/users/additional`、`/api/v2/users/review_movies` | 我的、个人资料、想看/看过 |
| Collections | `/api/v1/users/collected_*`、`/api/v1/users/recent_viewed` | 我的收藏、近期浏览 |
| Lists | `/api/v1/lists`、`/api/v1/lists/related`、`/api/v1/lists/{id}` | 清单 |
| Reviews | `/api/v1/reviews/hotly`、`/api/v1/movies/{id}/reviews` | 短评 |
| Articles | `/api/v1/articles` | AV资讯 |

付费、钱包、广告、在线观影接口保留在 OpenAPI 文件中，但不纳入本客户端实现范围。
