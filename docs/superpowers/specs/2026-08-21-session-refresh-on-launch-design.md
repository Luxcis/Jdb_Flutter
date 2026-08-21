# 进入应用时校验登录会话并刷新用户缓存 — 设计

日期：2026-08-21
状态：已批准

## 背景

当前应用在冷启动后直接进入主界面，本地缓存的登录会话（token + user）不会在校验
后刷新。若 token 已失效（过期 / 用户被删除），用户只有在访问需要鉴权的接口时才
会触发全局 `onAuthError` 被动登出，体验不佳。

需求：**每次进入应用时，若此前登录过，则调用用户信息接口刷新缓存并判断 token 是否
可用；不可用则提示用户登录过期，需要重新登录。**

## 决策记录

| 决策点 | 结论 |
|--------|------|
| 登录过期行为 | 自动登出并跳转登录页，登录页显示『登录已过期，请重新登录』提示 |
| 网络错误容忍度 | 仅明确的鉴权失败（`JWTVerificationError` / `NonExistentUser` / HTTP 401）才登出；断网/超时/500 保留会话，下次进入再试 |
| 缓存更新范围 | 校验成功后用最新 user 刷新整个会话缓存（token 不变），并触发 UI 刷新 |
| 触发时机 | 启动页加载域名成功后、进入主界面之前校验一次 |
| 实现方案 | 方案 B：独立 `SessionRefreshService` + `AuthProvider.updateUser`，启动页轻量串联 |

## 现状梳理

- `AuthProvider`（`lib/core/providers/auth_provider.dart`）：
  - 缓存 `_token` / `_user`，持久化到 `SharedPreferences['key_auth_session']`
  - `login({token, user})` 写会话；`logout()` 清会话；`isLogged` 判断是否登录
- `ApiTokenAuthenticationService`（`lib/features/profile/services/token_authentication_service.dart`）：
  - `authenticate(token)` → `GET /api/v1/users`（`Endpoints.users`，带候选 token，
    `suppressGlobalAuthError` 屏蔽全局登出回调）
  - 成功返回 user map；失败抛 `ApiException` / `DioException`
- `ApiException.isAuthError`：`JWTVerificationError` / `NonExistentUser` 判定
- `ResponseInterceptor`：HTTP 401 时若未 suppress 会触发 `onAuthError` 全局登出
- `StartupPage`：`StartupProvider.load()` 成功后 `context.go('/home')`

## 目标流程

```
App 冷启动 → StartupPage
  └─ StartupProvider.load() 成功（域名就绪）
       └─ SessionRefreshService.refresh()
            ├─ 未登录 → skipped → go('/home')
            ├─ 已登录 → GET /api/v1/users（带缓存 token）
            │    ├─ 成功 → AuthProvider.updateUser(最新 user) → success → go('/home')
            │    ├─ 鉴权失败 → AuthProvider.logout() → expired → go('/login?from=/home&reason=expired')
            │    └─ 网络/服务器错误 → failure → 保留会话 → go('/home')
```

## 组件设计

### 1. 新增 `lib/core/services/session_refresh_service.dart`

```dart
enum SessionRefreshStatus { success, expired, skipped, failure }

abstract interface class SessionRefreshService {
  Future<SessionRefreshStatus> refresh();
}

final class ApiSessionRefreshService implements SessionRefreshService {
  ApiSessionRefreshService({
    required AuthProvider auth,
    required TokenAuthenticationService tokenAuthentication,
  });

  Future<SessionRefreshStatus> refresh() async {
    final token = auth.token;
    if (token == null || token.isEmpty) return skipped;
    try {
      final user = await tokenAuthentication.authenticate(token);
      await auth.updateUser(user);
      return success;
    } on ApiException catch (e) {
      if (e.isAuthError) { await auth.logout(); return expired; }
      return failure;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) { await auth.logout(); return expired; }
      return failure;
    } catch (_) {
      return failure;
    }
  }
}
```

- 成功时调用 `AuthProvider.updateUser(user)`（见下）更新缓存，token 不变
- 鉴权失败调用 `auth.logout()` 清会话，返回 `expired`
- 其余异常返回 `failure`，保留会话

### 2. `AuthProvider` 新增方法

```dart
/// 用最新用户信息刷新当前会话（token 不变，写回持久化并通知 UI）。
Future<void> updateUser(Map<String, dynamic> user);
```

实现：复用 `_persistSession` 写入 `{'token': _token, 'user': user}`，更新 `_user`，
`notifyListeners()`。

### 3. `StartupPage` 变更

- 增加可选构造参数 `final SessionRefreshService? sessionRefreshService;`
  （保留 `const StartupPage()` 在路由中的现有用法）
- 默认构造：`ApiSessionRefreshService(auth: authProvider, tokenAuthentication: ApiTokenAuthenticationService(ApiClient.instance))`
- `StartupProvider.load()` 成功后执行 `refresh()`，按结果导航：
  - `success` / `skipped` / `failure` → `go('/home')`
  - `expired` → `go('/login?from=/home&reason=expired')`

### 4. `LoginPage` 变更

- 读 `GoRouterState` 查询参数 `reason`，若为 `expired` 则显示提示条
  『登录已过期，请重新登录』（红色提示，位于"请登录后继续"与表单之间）

## 错误处理与边界情况

| 场景 | 处理 |
|------|------|
| 未登录（无 token） | `skipped`，不发请求，直接进主界面 |
| 校验成功 | `updateUser` 刷新缓存（含计数），进主界面 |
| `JWTVerificationError` / `NonExistentUser` / HTTP 401 | `expired`：`logout()` → 跳登录页带 `reason=expired` |
| 断网 / 超时 / 服务器 500 | `failure`：保留会话，进主界面，下次进入再试 |
| 校验期间用户手动退出（竞态） | `logout()` 幂等，无副作用 |
| 启动加载失败（域名不可用） | 维持现有重试逻辑，不触发校验 |

## 测试策略

遵循项目现有模式（假 ApiClient + FakeAdapter / 假 Service 注入）：

| 测试文件 | 覆盖 |
|----------|------|
| `test/core/services/session_refresh_service_test.dart` | 未登录→skipped；成功→updateUser 且返回 success；鉴权失败→logout→expired；401→logout→expired；网络错误→保留会话→failure |
| `test/core/providers/auth_provider_test.dart`（扩展） | `updateUser` 持久化 + notify + token 不变 |
| `test/features/startup/startup_screen_test.dart`（扩展） | success/skipped/failure→go home；expired→go login 带 reason=expired |
| `test/features/auth/login_screen_test.dart`（扩展） | 带 reason=expired 显示提示；不带不显示 |

## 范围

- 不含：前后台切换校验（AppLifecycleState）、token 自动续期、强制登出弹窗
- 不含：修改 `ApiTokenAuthenticationService` 现有行为（复用现状）
