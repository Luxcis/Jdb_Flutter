# Debug 响应日志设计

## 目标

在每次 Dio 网络请求完成后输出请求参数、响应结果与响应内容，便于开发阶段定位接口问题。日志仅在 Debug
模式启用，不改变 Release/Profile 构建行为。日志输出使用 `logger` 包统一格式化，避免手写长字符串分段导致响应内容阅读困难。

## 范围

- 覆盖 `ApiClient` 统一 Dio 实例发出的正常响应、HTTP 错误、连接错误和域名切换产生的重试请求。
- 正常响应记录请求方法、完整 URI、查询参数、请求体、HTTP 状态码、结果和业务响应解包前的原始响应内容。
- 错误响应记录请求方法、完整 URI、查询参数、请求体、HTTP 状态码或 Dio
  错误类型、结果和可用的原始响应内容；没有响应内容时明确输出“无响应内容”。
- 不记录请求头、Authorization Token 或 Cookie。
- 不修改现有响应解包、鉴权失效处理及域名切换逻辑。

## 方案

新增 `ResponseLoggingInterceptor`，放置在 `lib/core/network/interceptors/`。它通过 Dio 的 `onResponse`
和 `onError` 生命周期统一记录请求完成信息，并将响应继续交给现有拦截器链。

`ApiClient.create` 将该拦截器注册在 `ResponseInterceptor` 之前，使日志获得尚未解包的服务端原始响应。日志拦截器以
`kDebugMode` 作为默认启用条件，通过 `logger` 的 `Logger`、无边框 `PrettyPrinter` 和自定义 `LogOutput`
统一输出。默认输出仍走 Flutter `debugPrint`，并设置较宽的 `wrapWidth`
；测试注入输出也复用相同宽度分段，避免平台日志单行限制直接截断超长响应。

每个请求在 `RequestOptions.extra` 中维护内部已记录标记，并在每次进入 Dio 请求链时重置该标记。HTTP 200
但业务信封表示失败时，原始响应先由 `onResponse` 记录，随后 `ResponseInterceptor` 转换为 `DioException`
；日志拦截器的 `onError` 检测标记后不重复输出。连接错误或非成功 HTTP 状态没有经过 `onResponse` 时，由
`onError` 记录一次。重试请求会重新进入请求链，因此拥有独立的日志记录机会。

域名切换后的重试是一次新的 Dio 请求尝试，因此原始失败尝试与重试结果分别记录，便于还原真实网络过程。

## 日志格式

每条响应日志使用 `logger` 输出稳定字段行，`Body` 使用紧凑 JSON 字符串：

```text
HTTP RESPONSE
Method: GET
URI: https://example.test/api/v1/movies
Query: {"page":1}
Request Body: 无请求内容
Status: 200
Result: SUCCESS
Body: {"success":1,"data":{"id":"1"}}
```

错误响应的 `Result` 为 `ERROR`。查询参数取自 `RequestOptions.queryParameters`，请求体取自
`RequestOptions.data`；缺失时分别输出空对象或“无请求内容”。当没有 HTTP 状态码或响应体时，分别输出 Dio
错误类型和“无响应内容”。Map/List 请求参数及响应使用 `jsonEncode` 输出紧凑
JSON；其他类型安全转换为字符串，日志格式化失败不能影响请求结果。

## 可测试性

拦截器构造函数允许注入日志输出回调和启用开关，生产环境使用默认值，测试使用内存列表捕获 `logger`
最终输出行，不依赖控制台输出。

测试覆盖：

1. 成功响应输出查询参数、请求体、状态、成功结果和原始响应内容，并继续传递响应。
2. 带响应体的错误输出请求参数、失败结果和响应内容，并继续传递异常。
3. 无响应体的连接错误输出错误类型和“无响应内容”。
4. 禁用时不输出任何日志。
5. `Body` 以紧凑 JSON 字符串输出；超长响应内容不再按固定 800 字符硬切块，拼接 Logger 输出后仍可还原完整内容。
6. 已记录的业务失败进入 `onError` 时不会重复输出。
7. `ApiClient.create` 注册日志拦截器，端到端请求可触发日志行为。

## 验收标准

- Debug 构建中，每次实际 Dio 请求尝试完成后恰好产生一条响应日志。
- 日志包含请求标识、查询参数、请求体、响应结果与完整可字符串化响应内容。
- Release/Profile 构建不输出该响应日志。
- 现有响应解包、鉴权异常和域名切换测试保持通过。
- `dart format`、`flutter analyze`、相关网络测试及完整 `flutter test` 均通过。
