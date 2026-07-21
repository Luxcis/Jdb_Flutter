# API Reference (api-reference.md)

> 基于 OpenAPI 3.0.3 规范 `jdb_api_openapi.json`，共 99 个路径、107 个操作。

## 1. Base URL

| 环境   | URL                          | 说明                   |
|------|------------------------------|----------------------|
| 生产环境 | `https://jdforrepam.com`     | App 实际使用的主域名         |
| 测试环境 | `https://staging.letidi.com` | 开发测试域名，App 首次安装时的默认值 |

此外，图片、封面、头像等静态资源统一使用 CDN 域名：`https://tp.spfcas.com/rhe951l4q/`

### 域名动态切换机制

App 采用多域名热切换策略，以应对主域名被封禁的情况。整个机制分为初始化、故障检测、备用域名切换三个阶段。

#### 1.1 初始化（首次启动）

App 首次安装后，内置的默认 Base URL 为 `https://staging.letidi.com`。启动时调用以下接口获取生产域名和备用域名列表：

**请求**:

```
GET /api/v1/startup?platform=android&app_channel=google&app_version=1.9.29&app_version_number=35
```

**响应**（关键字段）:

```json
{
  "success": 1,
  "data": {
    "backup_domains_data": "JCxJQTR1DerICeuy4lmmW...（Base64 加密的备用域名数据）",
    "settings": {
      ...
    },
    "user": {
      "promotion_code": null
    }
  }
}
```

响应中的 `backup_domains_data` 字段是一段 Base64 加密数据，解密后包含以下信息：

| 字段                   | 说明                     |
|----------------------|------------------------|
| `apiDomains`         | 可用 API 域名列表（数组，按优先级排序） |
| `backupUrls`         | 备用 URL 列表              |
| `unblockedAppDomain` | 当前未被封禁的域名              |
| `permanentAppDomain` | 永久域名（如 `javdb.com`）    |
| `imageEndpoint`      | 图片服务端点                 |

App 收到响应后，将主域名写入本地存储的 `key_baseurl` 键，后续所有 API 请求使用该域名。

#### 1.2 故障检测与域名切换

每个 API 请求发出前，App 会先检查网络连接状态。若无网络则提示"无网络连接"。

请求过程中，通过错误拦截器检测以下情况触发域名切换：

**触发条件**：当请求返回 HTTP 状态码 608（域名封禁/服务不可用）时，或当前域名请求持续失败时。

**切换流程**：

1. 调用 `AppCommon.changeCurrentUrl()` 从 `backup_domains_data` 解密出的 `apiDomains` 列表中选取下一个可用域名
2. 将新域名写入本地存储的 `key_baseurl` 键
3. 重新初始化 HTTP 客户端（Dio），使用新域名作为 Base URL
4. 用新域名重新发送刚才失败的请求

**特殊情况 — 中国大陆用户**：
当 App 检测到当前使用的域名不是主域名 `jdforrepam.com` 时（即已切换到备用域名），会向用户弹出提示："
切换到大陆可用域名"。这表明备用域名可能是面向大陆用户的镜像节点。

#### 1.3 完整域名生命周期

```
首次安装
  │
  ▼
默认域名: staging.letidi.com
  │
  ▼
调用 GET /api/v1/startup
  │
  ▼
获取 backup_domains_data → 解密得到 apiDomains 列表
  │
  ▼
写入主域名 jdforrepam.com 到本地存储
  │
  ▼
正常请求 ──────► 成功？继续使用
  │
  │ 失败（608/持续错误）
  ▼
从 apiDomains 列表选取下一个域名
  │
  ▼
更新本地存储 + 重新初始化 HTTP 客户端
  │
  ▼
用新域名重试请求 ──────► 成功？继续使用新域名
  │
  │ 主域名恢复
  ▼
下次启动时通过 startup 接口重新获取最新域名列表
```

#### 1.4 域名相关接口

除了 startup 接口，关于页面也提供域名信息：

**请求**:

```
GET /api/v1/about?app_channel=google
```

**响应**:

```json
{
  "success": 1,
  "data": [
    [
      {
        "name": "官網(最新域名)",
        "meta": "javdb574.com",
        "url": "https://javdb574.com"
      },
      {
        "name": "官網(永久域名)",
        "meta": "javdb.com",
        "url": "https://javdb.com"
      },
      {
        "name": "App安裝",
        "meta": "app.javdb574.com",
        "url": "https://app.javdb574.com"
      }
    ]
  ]
}
```

该接口返回的是面向用户展示的官网域名列表，与 API 域名切换机制相互独立，但可交叉参考判断当前可用域名。

## 2. 认证方式

### 2.1 签名认证（所有请求必须）

每个请求必须携带 `jdsignature` 请求头：

```
jdsignature: {timestamp}.{d2}.{md5(timestamp + d1)}
```

详见 [ALGORITHM.md](./ALGORITHM.md)。

### 2.2 Bearer Token 认证（需登录的接口）

登录成功后获取 JWT token，在后续请求中携带：

```
Authorization: Bearer {token}
```

### 2.3 请求头清单

| Header            | 值                             | 必填    | 说明             |
|-------------------|-------------------------------|-------|----------------|
| `jdsignature`     | `{timestamp}.{d2}.{md5_hash}` | 是     | 动态签名           |
| `authorization`   | `Bearer {jwt_token}`          | 仅认证接口 | 登录后获取          |
| `accept-language` | `zh-CN`                       | 推荐    | 语言设置           |
| `connection`      | `keep-alive`                  | 推荐    | 固定值            |
| `User-Agent`      | `Dart/3.5 (dart:io)`          | 可选    | 模拟 Flutter 客户端 |

## 3. 统一响应格式

```json
{
  "success": 1,
  "action": null,
  "message": null,
  "data": {}
}
```

| 字段        | 类型                  | 说明           |
|-----------|---------------------|--------------|
| `success` | int                 | 1=成功, 0=失败   |
| `action`  | string\|null        | 错误动作标识       |
| `message` | string\|null        | 消息（错误时为繁体中文） |
| `data`    | object\|array\|null | 响应数据         |

### 错误码

| action                 | message         | 说明               |
|------------------------|-----------------|------------------|
| `ParameterInvalid`     | 參數不能爲空: {field} | 缺少必需参数           |
| `InvalidSignature`     | 無效的簽名           | jdsignature 验证失败 |
| `JWTVerificationError` | 請登錄帳號           | 需要登录             |
| `NonExistentUser`      | 帳號不存在           | 用户不存在            |

## 4. API 接口分类

### 4.1 Auth — 认证与注册

| 方法   | 路径                                     | 认证 | 说明               |
|------|----------------------------------------|----|------------------|
| POST | `/api/v1/sessions`                     | 否  | 登录（返回 JWT token） |
| POST | `/api/v1/users`                        | 否  | 注册               |
| POST | `/api/v1/users/activate_registration`  | 否  | 激活注册             |
| POST | `/api/v1/users/resend_activation_code` | 否  | 重发激活码            |
| POST | `/api/v1/users/forgot_password`        | 否  | 忘记密码（发送验证码）      |
| POST | `/api/v1/users/reset_password`         | 否  | 重置密码             |

**登录请求体**:

```json
{
  "username": "zzj1999@yahoo.com",
  "password": "949527zzj",
  "device_uuid": "设备唯一标识",
  "device_name": "设备名称",
  "device_model": "设备型号",
  "platform": "android",
  "system_version": "14",
  "app_channel": "google",
  "app_version": "1.9.29",
  "app_version_number": "35"
}
```

**登录响应**:

```json
{
  "success": 1,
  "data": {
    "user": {
      "id": 1874235,
      "username": "luxcis",
      "email": "...",
      "is_vip": false,
      "vip_expired_at": null,
      "want_watch_count": 2,
      "watched_count": 0,
      "share_url": "https://app.javdb574.com/?source=hvjarw",
      "promotion_code": "hvjarw"
    },
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "banner_type": "payment",
    "following_tags": [
      ...
    ]
  }
}
```

### 4.2 User — 用户信息

| 方法   | 路径                              | 认证 | 说明     |
|------|---------------------------------|----|--------|
| GET  | `/api/v1/users`                 | 是  | 获取用户信息 |
| GET  | `/api/v1/users/additional`      | 是  | 用户附加信息 |
| PUT  | `/api/v1/users/additional`      | 是  | 更新附加信息 |
| POST | `/api/v1/users/change_password` | 是  | 修改密码   |
| POST | `/api/v1/users/change_username` | 是  | 修改用户名  |
| POST | `/api/v1/users/feedback`        | 是  | 用户反馈   |

### 4.3 Movie — 影片内容

| 方法   | 路径                                                     | 认证 | 说明                                                 |
|------|--------------------------------------------------------|----|----------------------------------------------------|
| GET  | `/api/v1/movies/latest`                                | 否  | 最新影片（query: type, page, limit）                     |
| GET  | `/api/v1/movies/recommend`                             | 否  | 推荐影片（query: period）                                |
| GET  | `/api/v1/movies/recommend_periods`                     | 否  | 推荐周期                                               |
| GET  | `/api/v1/movies/top`                                   | 是  | Top 排行（query: type, year, page, limit）             |
| GET  | `/api/v1/movies/may_also_like`                         | 否  | 猜你喜欢                                               |
| GET  | `/api/v1/movies/tags`                                  | 否  | 按标签筛选（query: type, sort_by, order_by, page, limit） |
| GET  | `/api/v4/movies/{movie_id}`                            | 否  | 影片详情 V4                                            |
| GET  | `/api/v1/movies/{movie_id}/play`                       | 是  | 获取播放信息（M3U8）                                       |
| GET  | `/api/v1/movies/{movie_id}/resume_play`                | 是  | 恢复播放                                               |
| GET  | `/api/v1/movies/{movie_id}/magnets`                    | 否  | 磁力链接列表                                             |
| GET  | `/api/v1/movies/{movie_id}/reviews`                    | 否  | 影片评论列表                                             |
| POST | `/api/v1/movies/{movie_id}/reviews`                    | 是  | 创建影评（body: score, content, status）                 |
| PUT  | `/api/v1/movies/{movie_id}/reviews/{review_id}`        | 是  | 更新影评                                               |
| POST | `/api/v1/movies/{movie_id}/reviews/{review_id}/like`   | 是  | 评论点赞                                               |
| POST | `/api/v1/movies/{movie_id}/reviews/{review_id}/report` | 是  | 评论举报                                               |

### 4.4 Search — 搜索

| 方法  | 路径                      | 认证 | 说明                         |
|-----|-------------------------|----|----------------------------|
| GET | `/api/v2/search`        | 否  | 综合搜索（query: q, type, code） |
| GET | `/api/v2/search_image`  | 否  | 图片搜索                       |
| GET | `/api/v1/search_magnet` | 否  | 磁力搜索（query: q）             |

### 4.5 Actor — 演员/导演/制作商/发行商

| 方法   | 路径                                                | 认证 | 说明                                          |
|------|---------------------------------------------------|----|---------------------------------------------|
| GET  | `/api/v1/actors`                                  | 否  | 演员列表                                        |
| GET  | `/api/v1/actors/recommend`                        | 否  | 推荐演员                                        |
| GET  | `/api/v1/actors/{actor_id}`                       | 否  | 演员详情（query: sort_by, order_by, page, limit） |
| POST | `/api/v1/actors/{actor_id}/collect_actions`       | 是  | 收藏/取消收藏                                     |
| POST | `/api/v1/actors/batch_uncollection`               | 是  | 批量取消收藏                                      |
| GET  | `/api/v1/directors`                               | 否  | 导演列表                                        |
| GET  | `/api/v1/directors/{director_id}`                 | 否  | 导演详情                                        |
| POST | `/api/v1/directors/{director_id}/collect_actions` | 是  | 收藏导演                                        |
| GET  | `/api/v1/makers`                                  | 否  | 制作商列表                                       |
| GET  | `/api/v1/makers/{maker_id}`                       | 否  | 制作商详情                                       |
| POST | `/api/v1/makers/{maker_id}/collect_actions`       | 是  | 收藏制作商                                       |
| GET  | `/api/v1/publishers/{publisher_id}`               | 否  | 发行商详情                                       |

### 4.6 Series — 系列与编号

| 方法   | 路径                                           | 认证 | 说明                             |
|------|----------------------------------------------|----|--------------------------------|
| GET  | `/api/v1/series`                             | 否  | 系列列表（query: page, limit, type） |
| GET  | `/api/v1/series/letters`                     | 否  | 系列字母索引                         |
| GET  | `/api/v1/series/{series_id}`                 | 否  | 系列详情                           |
| POST | `/api/v1/series/{series_id}/collect_actions` | 是  | 收藏系列                           |
| GET  | `/api/v1/codes/{code_id}`                    | 否  | 编号详情                           |
| POST | `/api/v1/codes/{code_id}/collect_actions`    | 是  | 收藏编号                           |

### 4.7 Ranking — 排行榜

| 方法  | 路径                          | 认证 | 说明                        |
|-----|-----------------------------|----|---------------------------|
| GET | `/api/v1/rankings`          | 否  | 综合排名（query: type, period） |
| GET | `/api/v1/rankings/actors`   | 否  | 演员排名（query: type, period） |
| GET | `/api/v1/rankings/playback` | 否  | 播放排名（query: period）       |

### 4.8 Review — 评论

| 方法   | 路径                                | 认证 | 说明                                                         |
|------|-----------------------------------|----|------------------------------------------------------------|
| GET  | `/api/v1/reviews/hotly`           | 否  | 热门评论（query: period）                                        |
| POST | `/api/v1/reviews/hotly`           | 是  | 评论点赞                                                       |
| GET  | `/api/v2/users/{user_id}/reviews` | 否  | 用户评论列表                                                     |
| GET  | `/api/v2/users/review_movies`     | 是  | 已评价电影（query: status, type, sort_by, order_by, page, limit） |

### 4.9 List — 片单

| 方法     | 路径                                        | 认证 | 说明                                |
|--------|-------------------------------------------|----|-----------------------------------|
| GET    | `/api/v1/lists`                           | 是  | 片单列表（query: sort_by, page, limit） |
| POST   | `/api/v1/lists`                           | 是  | 创建片单（body: name, movie_id）        |
| GET    | `/api/v1/lists/simple`                    | 否  | 简版片单                              |
| GET    | `/api/v1/lists/related`                   | 否  | 相关片单                              |
| GET    | `/api/v1/lists/{list_id}`                 | 否  | 片单详情                              |
| PUT    | `/api/v1/lists/{list_id}`                 | 是  | 更新片单                              |
| DELETE | `/api/v1/lists/{list_id}`                 | 是  | 删除片单                              |
| POST   | `/api/v1/lists/{list_id}/collect_actions` | 是  | 收藏片单                              |
| POST   | `/api/v1/lists/{list_id}/movie_actions`   | 是  | 添加/移除影片                           |

### 4.10 Tag — 标签

| 方法     | 路径                                     | 认证 | 说明                             |
|--------|----------------------------------------|----|--------------------------------|
| GET    | `/api/v2/tags`                         | 否  | 标签列表（query: type, page, limit） |
| POST   | `/api/v1/following_tags`               | 是  | 关注标签（body: name, value）        |
| POST   | `/api/v1/following_tags/batch_push`    | 是  | 批量关注                           |
| POST   | `/api/v1/following_tags/batch_destroy` | 是  | 批量取消关注                         |
| DELETE | `/api/v1/following_tags/{tag_id}`      | 是  | 取消关注                           |
| PUT    | `/api/v1/following_tags/{tag_id}/sort` | 是  | 更新排序（body: priority）           |

### 4.11 Collection — 收藏

| 方法  | 路径                                  | 认证 | 说明     |
|-----|-------------------------------------|----|--------|
| GET | `/api/v1/users/collected_actors`    | 是  | 收藏的演员  |
| GET | `/api/v1/users/collected_codes`     | 是  | 收藏的编号  |
| GET | `/api/v1/users/collected_directors` | 是  | 收藏的导演  |
| GET | `/api/v1/users/collected_lists`     | 是  | 收藏的片单  |
| GET | `/api/v1/users/collected_makers`    | 是  | 收藏的制作商 |
| GET | `/api/v1/users/collected_series`    | 是  | 收藏的系列  |
| GET | `/api/v1/users/recent_viewed`       | 是  | 最近浏览   |

### 4.12 Article — 文章

| 方法  | 路径                              | 认证 | 说明                       |
|-----|---------------------------------|----|--------------------------|
| GET | `/api/v1/articles`              | 否  | 文章列表（query: page, limit） |
| GET | `/api/v1/articles/{article_id}` | 否  | 文章详情                     |

### 4.13 Ad — 广告

| 方法  | 路径                       | 认证 | 说明     |
|-----|--------------------------|----|--------|
| GET | `/api/v1/ads`            | 否  | 广告配置   |
| GET | `/api/v1/ads/splash_log` | 否  | 开屏广告日志 |

### 4.14 Wallet — 钱包

| 方法     | 路径                                                     | 认证 | 说明       |
|--------|--------------------------------------------------------|----|----------|
| GET    | `/api/v1/wallets`                                      | 是  | 钱包信息     |
| GET    | `/api/v1/wallets/rebate_logs`                          | 是  | 返利记录     |
| GET    | `/api/v1/wallets/withdraw_logs`                        | 是  | 提现记录     |
| POST   | `/api/v2/wallets/withdraw`                             | 是  | 发起提现     |
| POST   | `/api/v1/wallets/bind_withdraw_account`                | 是  | 绑定提现账户   |
| GET    | `/api/v1/wallets/binded_withdraw_accounts`             | 是  | 已绑定账户    |
| DELETE | `/api/v1/wallets/unbind_withdraw_account/{account_id}` | 是  | 解绑       |
| GET    | `/api/v1/wallets/sfpay_banks`                          | 是  | 银行列表     |
| GET    | `/api/v1/wallets/usdt_chain_types`                     | 是  | USDT 链类型 |
| POST   | `/api/v1/wallets/send_verification_email`              | 是  | 发送验证邮件   |
| POST   | `/api/v1/wallets/verify_email`                         | 是  | 验证邮箱     |

### 4.15 Payment — 会员支付

| 方法   | 路径                            | 认证 | 说明                                                 |
|------|-------------------------------|----|----------------------------------------------------|
| GET  | `/api/v3/plans`               | 否  | 会员套餐 V3（query: platform, app_channel, app_version） |
| GET  | `/api/v4/plans`               | 否  | 会员套餐 V4                                            |
| POST | `/api/v2/plans/payment_order` | 是  | 创建支付订单 V2                                          |
| POST | `/api/v3/plans/payment_order` | 是  | 创建支付订单 V3                                          |

### 4.16 Other — 其他

| 方法  | 路径                          | 认证 | 说明                                                                     |
|-----|-----------------------------|----|------------------------------------------------------------------------|
| GET | `/api/v1/startup`           | 否  | 应用启动初始化（query: platform, app_channel, app_version, app_version_number） |
| GET | `/api/v1/about`             | 否  | 关于页面（query: app_channel）                                               |
| GET | `/api/v1/helps`             | 否  | 帮助文档                                                                   |
| GET | `/api/v1/magnet_apps`       | 否  | 磁力应用                                                                   |
| GET | `/api/v1/debug_logging`     | 否  | 调试日志开关                                                                 |
| GET | `/api/v1/logs/movie_played` | 是  | 播放记录上报                                                                 |
| GET | `/api/v2/logs/activated`    | 否  | 激活日志                                                                   |

## 5. 通用查询参数

| 参数            | 类型     | 说明              | 使用接口                                   |
|---------------|--------|-----------------|----------------------------------------|
| `page`        | int    | 页码（从 1 开始）      | 所有分页列表                                 |
| `limit`       | int    | 每页条数            | 所有分页列表                                 |
| `type`        | int    | 类型筛选            | movies/latest, movies/tags, rankings 等 |
| `sort_by`     | string | 排序字段            | movies/tags, reviews, lists 等          |
| `order_by`    | string | 排序方向（asc/desc）  | watched, reviews 等                     |
| `period`      | string | 时间周期（如 monthly） | rankings, reviews/hotly                |
| `q`           | string | 搜索关键词           | search, search_magnet                  |
| `app_channel` | string | 渠道标识            | startup, about, users                  |

## 6. 代码示例

### 6.1 Python

```python
import hashlib, time, requests
from urllib.parse import urlencode

D1 = "71cf27bb3c0bcdf207b64abecddc970098c7421ee7203b9cdae54478478a199e7d5a6e1a57691123c1a931c057842fb73ba3b3c83bcd69c17ccf174081e3d8aa"
D2 = "lpw6vgqzsp"
BASE = "https://jdforrepam.com"

def gen_signature():
    ts = int(time.time())
    md5_h = hashlib.md5((str(ts) + D1).encode()).hexdigest()
    return f"{ts}.{D2}.{md5_h}"

def api_get(path, token=None, **params):
    h = {"accept-language": "zh-CN", "connection": "keep-alive", "jdsignature": gen_signature()}
    if token: h["authorization"] = f"Bearer {token}"
    if params: path = f"{path}?{urlencode(params)}"
    return requests.get(f"{BASE}{path}", headers=h)

def api_post(path, token=None, body=None):
    h = {"accept-language": "zh-CN", "connection": "keep-alive", "jdsignature": gen_signature()}
    if token: h["authorization"] = f"Bearer {token}"
    return requests.post(f"{BASE}{path}", headers=h, json=body)

# 登录
r = api_post("/api/v1/sessions", body={
    "username": "your@email.com", "password": "yourpassword",
    "device_uuid": "uuid", "device_name": "name", "device_model": "model",
    "platform": "android", "system_version": "14",
    "app_channel": "google", "app_version": "1.9.29", "app_version_number": "35"
})
token = r.json()["data"]["token"]

# 搜索
r = api_get("/api/v2/search", q="SSIS", page=1)

# 影片详情
r = api_get("/api/v4/movies/xAenVV")

# 获取播放信息（需登录）
r = api_get("/api/v1/movies/xAenVV/play", token=token)
```

### 6.2 JavaScript / TypeScript

```typescript
const D1 = "71cf27bb3c0bcdf207b64abecddc970098c7421ee7203b9cdae54478478a199e7d5a6e1a57691123c1a931c057842fb73ba3b3c83bcd69c17ccf174081e3d8aa";
const D2 = "lpw6vgqzsp";
const BASE = "https://jdforrepam.com";

function genSignature(): string {
  const ts = Math.floor(Date.now() / 1000);
  const md5Input = ts + D1;
  // 使用 crypto-js 或 Web Crypto API 计算 MD5
  const md5Hash = CryptoJS.MD5(md5Input).toString();
  return `${ts}.${D2}.${md5Hash}`;
}

async function apiGet(path: string, token?: string, params?: Record<string, any>) {
  const url = params ? `${BASE}${path}?${new URLSearchParams(params)}` : `${BASE}${path}`;
  const headers: Record<string, string> = {
    "accept-language": "zh-CN",
    "connection": "keep-alive",
    "jdsignature": genSignature(),
  };
  if (token) headers["authorization"] = `Bearer ${token}`;
  return fetch(url, { headers });
}
```

## 7. 相关文件

| 文件                     | 说明                                             |
|------------------------|------------------------------------------------|
| `jdb_api_openapi.json` | OpenAPI 3.0.3 规范文件（可导入 Swagger/Apifox/Postman） |
| `ALGORITHM.md`         | 签名算法详细说明                                       |
| `jdb_api.py`           | Python API 客户端（硬编码签名）                          |
| `AGENTS.md`            | 项目完整逆向记录                                       |
