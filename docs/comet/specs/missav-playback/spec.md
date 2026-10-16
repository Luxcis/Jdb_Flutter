# 影片在线播放（MissAV 正片）

## 概述

影片详情页的「正片」入口按影片番号在线播放 MissAV 片源：应用用 Cronet（Chromium 网络栈）抓取 MissAV 影片页 → 解码 Dean Edwards packer 混淆拿到 surrit 播放列表地址 → media_kit 携带 missav Referer 直连播放 HLS（多码率 master、音轨内嵌）。解析在播放页内进行，失败可重试；退出播放页即停止取流。

来源：`docs/main/missav/`（README.md 的播放链路与反爬结论、server.js 的头注入与取消语义、player.html 的解析算法）。本规格在 app 内实现等价能力；不建应用内中继，播放由播放器直连（形状等价于来源的 `/page` + 直连流，取消语义等价于来源的断开终止上游）。

## 解析管线（番号 → 播放地址）

- 输入为影片番号（`MovieDetail.number`）。
- 番号规范化：完整 missav 链接取末段路径；去除空白、统一小写；不猜测其他格式。规范化结果用于页面请求。
- 页面请求：`GET https://missav.live/ja/{code}`，注入浏览器 UA 与 `Accept-Language`；HTTP 客户端为 Cronet（`CronetClient`，Chrome 同系指纹，通过 WAF 指纹筛选）；非 Android 或测试环境使用注入的替代客户端。
- packer 解码：对页面内嵌 `eval(function(p,a,c,k,e,d)…` 混淆脚本执行等价 unPacker（支持 radix 16 与 62；处理 `\x` / `\u` 等转义）；解码产物与原文合并。
- UUID 提取：在（解码产物 + 原文）中匹配 `surrit\.com/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})`，取首个匹配。
- 正则兜底：没有任何 packer 可解码时，直接在原文中按 `surrit.com/{uuid}/playlist.m3u8` 形态提取。
- 输出：master 播放列表 URL（`https://surrit.com/{uuid}/playlist.m3u8`）与播放请求头（`Referer: https://missav.live/ja/`、浏览器 UA）。
- 任一环节失败 → 解析以失败结束，给出可展示的中文原因；不抛出未捕获异常。

### Scenario: 解析成功得到播放地址

Given 番号在 MissAV 有对应影片页且页面包含 packer 混淆的 surrit 地址
When 触发解析
Then 返回 `https://surrit.com/{uuid}/playlist.m3u8` 形态的播放地址与 Referer/UA 请求头

### Scenario: packer 解码支持两种 radix 与转义

Given 页面含 radix 16 或 radix 62 的 packer 混淆脚本（含 `\x` / `\u` 转义）
When 执行解码
Then 解出的文本包含正确的 surrit UUID，不因转义导致解码失败

### Scenario: 无 packer 时正则兜底

Given 页面未使用 packer 混淆但含明文 `surrit.com/{uuid}/playlist.m3u8`
When 触发解析
Then 仍能提取到播放地址

### Scenario: 番号规范化容错

Given 输入为完整 missav 链接（含语言段与路径）或带空格/大小写差异的纯番号
When 执行规范化
Then 输出小写、无空白的番号并用于页面请求

### Scenario: 解析失败返回可读原因

Given 番号不存在、页面请求非 200 或页面中找不到 surrit 地址
When 触发解析
Then 解析以失败结束并给出可展示的原因，播放页进入失败状态

## 播放

- 播放器以 HLS 直接播放 surrit master 播放列表，请求统一携带 Referer 与 UA（播放器 HTTP 头注入）。
- 多码率由播放器自适应；不提供画质选择 UI。
- Android 视频渲染走 MediaCodec 直渲染输出（不经 EGL/GL 上下文），以保证 GL 上下文不可用的运行环境（如模拟器）同样能出画；渲染路径与解码路径配套（MediaCodec 硬件解码 + 直接渲染输出）。
- 起播时序：先建立播放画面输出（surface）并与其关联，再开始播放；不采用「先开始播放、后中途切换视频输出」的顺序，避免黑屏或视频管线卡死。
- 播放页复用现有 `MoviePreviewScreen` 操作层与手势能力（标题、返回、播放/暂停、进度、长按倍速、亮度/音量滑、seek、同步显隐），行为与预告片一致。
- 播放页标题：正片来源显示影片标题；失败文案使用「在线播放失败」以区别于预告片文案。

### Scenario: 解析成功后自动开始播放

Given 解析已成功返回播放地址与请求头
When 播放页就绪
Then 自动开始播放（画面与进度推进），操作层可用

### Scenario: 播放请求携带 Referer

Given 在线正片播放已开始
When 检查播放器对 surrit 的请求构造
Then 请求携带 `Referer: https://missav.live/ja/` 与浏览器 UA

### Scenario: 画面输出就绪后起播

Given 播放地址已就绪且播放页开始建立视频画面输出
When 播放器开始播放
Then 视频输出已绑定到播放页的画面输出后再起播，画面可见（非全黑）且进度推进

### Scenario: MediaCodec 直渲染路径

Given Android 环境（含 GL/EGL 不可用的模拟器）
When 初始化播放器渲染
Then 使用 MediaCodec 直接渲染输出到播放页画面，经 MediaCodec 硬件解码播放，不需要 GL 上下文

## 失败与重试

- 解析失败与播放失败都在播放页以失败状态呈现：中文失败说明 + 「重试」按钮。
- 重试重新执行「解析 → 播放」全流程（重新抓页、重新解码）；不缓存失败结果，不自动重试循环。
- 失败时退出播放页返回详情页，入口保持可用。
- 播放链路的失败原因（播放器 error/fatal 级别日志的 prefix、级别与文本）写入设备日志，便于在真机定位；日志属于诊断输出，不改变用户可见的失败文案与交互。

### Scenario: 解析失败可原地重试恢复

Given 首次解析失败（例如网络不可达或番号不存在）
When 查看播放页
Then 显示失败状态与「重试」；条件恢复后点击重试，解析成功并开始播放

### Scenario: 播放失败可重试

Given 解析成功但播放器报错（例如 CDN 拒绝）
When 查看播放页
Then 显示失败状态与「重试」，点击重试重新走解析与播放

### Scenario: 播放失败原因写入日志

Given 播放器在播放链路报出 error 或 fatal 级信息（例如视频输出初始化失败、网络失败、解码失败）
When 查看设备日志
Then 日志包含该信息的 prefix、级别与文本，可据此定位失败环节

## 退出清理

- 退出播放页时释放播放器与其网络连接，不产生退出后继续拉流的路径。
- 解析中的在途请求在退出后不启动播放、不写页面状态（结果到达时页面已销毁则为无副作用）。

### Scenario: 退出播放页停止取流

Given 在线正片正在播放
When 退出播放页
Then 播放器被释放、无继续拉流；再次进入可重新解析并播放

### Scenario: 解析中退出无副作用

Given 解析请求仍在进行
When 退出播放页
Then 请求完成后不启动播放、不写入页面状态、不崩溃

## 依赖与构建

- 新增依赖 `cronet_http`（Android）。
- 以 embedded Cronet 为准（`--dart-define=cronetHttpNoPlay=true`），保证无 Google Play 服务的设备可用；CI 构建命令与 `RULES.md` 构建约定同步携带该 define。
- 支持平台：Android（与项目发布形态一致）；测试环境不实例化 Cronet（HTTP 客户端注入替身）。

### Scenario: 发布构建携带 embedded Cronet 配置

Given CI 或本地发布构建
When 检查构建命令（workflow / RULES.md）
Then 包含 `--dart-define=cronetHttpNoPlay=true`，APK 依赖 cronet-embedded 而非 play-services-cronet
