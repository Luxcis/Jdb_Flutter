# 目标

影片详情页新增「正片」在线播放入口：置于「剧照列表」（含预告片入口的横向区）最前、预告片播放入口之前；两个播放入口都带可见文本标识（「正片」「预告片」）。点击「正片」进入全屏播放页，按影片番号解析 MissAV 页面（解码 packer → 取得 surrit 播放列表）并开始在线播放，失败时可重试。

# 范围

- 影片详情页「预告片 / 剧照」区（`MovieScreenshotSection`，`lib/features/movie_detail/widgets/basic_info_sections.dart`）：新增「正片」播放入口卡（第一位），预告片入口卡（第二位，仅当 `previewVideoUrl` 非空），其后为剧照缩略图；两个入口卡都显示可见文本标识；区标题改为「正片 / 预告片 / 剧照」；区块显示条件放宽为恒定显示（Q3-A）。
- 详情页编排（`basic_info_widgets.dart` / `movie_detail_screen.dart`）：把番号（`MovieDetail.number`）与正片播放入口点击接通到播放页。
- 播放页（复用 `MoviePreviewScreen` 体系）：支持「在线正片」来源——进入后先解析取流地址（播放页内解析，Q2-A），成功后自动开始播放；解析/播放失败显示失败原因与「重试」；复用现有操作层（返回、播放/暂停、进度、长按倍速、亮度/音量滑、seek、同步显隐）。
- 取流组件（Q1-B：播放器直连 + Cronet 解析）：
  - 页面抓取与解析：用 `cronet_http`（CronetClient，Chromium 网络栈指纹）请求 `https://missav.live/{lang}/{code}`，注入浏览器 UA 与 Accept-Language；解码 Dean Edwards packer（radix 16/62）→ 提取 surrit UUID（正则兜底）→ 输出 master 播放列表 URL 与请求头（Referer 等）。
  - 播放：media_kit 直连 surrit master 播放列表（HLS 多码率自适应），请求携带 Referer `https://missav.live/ja/` 与浏览器 UA。
  - 番号规范化：完整 missav 链接与纯番号（大小写、空格容错）均可规范化为番号。
- 构建（Q1-B 的配套）：新增 `cronet_http` 依赖；以 embedded Cronet（`--dart-define=cronetHttpNoPlay=true`）为准，保证无 Google Play 服务的设备可用；CI 构建命令（`.github/workflows/compile_apk.yml`）同步携带该 define；构建约定写入 `RULES.md`。

## 目录结构

### 新建

- `lib/features/movie_detail/services/missav_page_parser.dart`（番号规范化、packer 解码、UUID/播放地址提取）
- `lib/features/movie_detail/services/missav_stream_resolver.dart`（页面抓取 + 播放地址与请求头输出；HTTP 客户端注入，Android 生产实现用 Cronet）
- `lib/features/movie_detail/models/missav_playback_source.dart`（如播放页参数需要：在线来源信息与已解析结果模型；实现细节以 Build 为准）
- `test/features/movie_detail/` 下对应新增单测与 widget 测试（parser、resolver、入口与播放页状态流转；含真实页面片段的离线 fixture）

### 修改

- `lib/features/movie_detail/widgets/basic_info_sections.dart`（区块入口、顺序与文本标识）
- `lib/features/movie_detail/widgets/basic_info_widgets.dart`（接通番号与正片点击、区块恒定显示）
- `lib/features/movie_detail/screens/movie_detail_screen.dart`（正片入口 → 播放页参数）
- `lib/features/movie_detail/screens/movie_preview_screen.dart`（在线来源：解析中/失败/重试状态；失败文案按来源区分）
- `lib/features/movie_detail/services/movie_preview_playback.dart`（播放请求头支持：Media httpHeaders）
- `lib/features/movie_detail/models/movie_preview_args.dart`（在线来源参数）
- `pubspec.yaml`（新增 `cronet_http`）
- `.github/workflows/compile_apk.yml`（构建命令携带 `--dart-define=cronetHttpNoPlay=true`）
- `RULES.md`（embedded Cronet 构建约定）
- `docs/comet/changes/missav-online-playback/specs/movie-detail-stills/spec.md`（区块入口层：正片入口、标识、恒定显示、标题）

### 删除

无。

### 明确不建

不移植 `player.html` 的桌面播放器 UI（表单、画质下拉、复制 m3u8、打开原站按钮）；不做 iframe/WebView 内嵌原站方案；不实现 seek 缩略图与预取；不做批量抓取；不建应用内本地中继（Q1-B 直连；若真机验证发现 libmpv 过不了 WAF，回退方案另行开 change）。

## Source coverage

- 覆盖边界：`docs/main/missav/` 整个文件夹（用户指定「文件夹中的示例和文档」），含 `README.md`、`server.js`、`player.html` 三个文件，全部已完整读取。
- 说明：来源材料为「逆向分析 + 桌面参考实现」，本 change 在 app（Android）内实现等价能力；来源中面向桌面浏览器的形态（iframe 禁令除外，见 S4）按分类表处理。

| 来源条目与位置 | 读取状态 | 需要保留的内容 | Spec 位置 | 验收 ID | 覆盖状态 | 理由或替代关系 |
| --- | --- | --- | --- | --- | --- | --- |
| S1：README.md「一、播放链路」整体流程（页面→packer→surrit master→HLS 变体/音轨内嵌/分片伪装/UUID 不可推算） | complete | app 侧必须复刻：抓页面、解码 packer、取 surrit master、以 HLS 播放（音轨内嵌无需另处理；UUID 只能来自页面） | specs/missav-playback/spec.md「解析管线」「播放」 | A2、A5 | covered | 当前有效需求 |
| S2：README.md「一」附注（EXT-X-TOKEN 说明行、seek 缩略图同 CDN） | complete | 播放列表中的未知说明行不阻塞播放；不实现缩略图预取 | — | — | non-goal | 播放器（libmpv）自带处理；缩略图与在线播放体验无关 |
| S3：README.md「二、反爬机制清单」第 1–2、5、6、7 项（Referer 白名单、分片 403、429 限速、packer 混淆、镜像白名单） | complete | 页面/playlist/分片请求必须注入 missav Referer；客户端须能通过 WAF 指纹筛选（Cronet 用于页面；libmpv 用于流，真机验证）；解码 packer 才可拿到 UUID | specs/missav-playback/spec.md「取流约束」 | A4、A5 | covered | 当前有效需求 |
| S4：README.md「二」备注（主站无 ACAO、`X-Frame-Options: SAMEORIGIN` → 不能 iframe 内嵌） | complete | 不采用 WebView/iframe 内嵌 missav 页面播放 | — | — | non-goal | 技术不可行（来源实验结论） |
| S5：README.md「三、本项目交付」+ 三路由说明 + player.html 解析容错 3 条（packer 解码 radix16/62、e2e 正则兜底、中继探测） | complete | app 内提供等价能力：页面抓取通道（Cronet）、播放由播放器直连；解析容错两级保留；中继探测为桌面浏览器特有，app 内不需要 | specs/missav-playback/spec.md「解析管线」 | A2、A3、A5 | covered | 结构等价移植（Q1-B：无媒体中继，播放器直连带 Referer） |
| S6：README.md「四、复现关键实验」curl 矩阵 | complete | 作为验证手段参考（本机 curl 基线已复核：playlist 200 / 页面 200；dart:io 与 ffmpeg 均 403） | — | — | background | 验证参考，不产生产品行为 |
| S7：README.md「五、局限」（WAF 黑盒、收紧可切 curl-impersonate、番号与 UUID 无对应关系、个人使用勿批量） | complete | 解析失败（番号不存在/无对应页）自然失败并可重试；不做批量与后台自动抓取 | specs/missav-playback/spec.md「失败与重试」 | A3 | covered | 当前有效约束 |
| S8：server.js 头注释（必须用 curl 子进程的 TLS 指纹原因） | complete | 上游客户端选型受 WAF 指纹约束；本机实测 dart:io 与 ffmpeg 均 403、curl 200；据此选 Cronet（浏览器同系指纹）用于页面请求 | specs/missav-playback/spec.md「取流约束」 | A4 | covered | Q1-B 结论：不嵌入 curl/libcurl；流侧由 libmpv 直连（真机验证项，见验证预期） |
| S9：server.js 转发实现（头白名单转发、Range 透传、流式回传、客户端断开终止上游、多段头块扫描） | complete | 保留等价语义：退出播放页即停止取流（播放器释放），不产生后台继续拉流的路径；Range 由 libmpv 自行处理 | specs/missav-playback/spec.md「退出清理」 | A6 | covered | 无应用内中继（Q1-B），取消语义等价保留 |
| S10：server.js 路由与头注入（`/page/{code}`、`/hls/{UUID}/...`、UA/Referer/Accept-Language、路径校验、超时） | complete | 页面请求注入 UA/Accept-Language；流请求注入 Referer/UA；请求超时与失败可读 | specs/missav-playback/spec.md「解析管线」「播放」 | A4、A5 | covered | 当前有效需求 |
| S11：player.html 中继探测与 `relayUrl` 拼接（localStorage→同源→127.0.0.1:8931） | complete | app 内播放器直连上游，无中继地址拼接需求 | — | — | superseded | 桌面浏览器跨进程场景特有；Q1-B 无中继 |
| S12：player.html 解析核心（`unesc`/`radix`/`unpack`/`PACK_RE`、`extractSurritMaster`、`normalizeCode`、`resolveMaster` 容错） | complete | Dart 移植：packer 解码（radix 16/62）、UUID 提取（取首个匹配）、番号规范化（完整链接/纯番号、大小写与空格容错）、解析失败信息聚合 | specs/missav-playback/spec.md「解析管线」 | A5、A3 | covered | 算法等价移植并补单测（离线 fixture） |
| S13：player.html 播放与交互（hls.js 加载与错误重试提示、画质选择、自动播放与拦截提示、停止清理、复制 m3u8/打开原站） | complete | 保留：自动播放、播放失败提示与重试、停止清理；画质选择、复制 m3u8、打开原站按钮不移植 | specs/missav-playback/spec.md「播放」「失败与重试」「退出清理」 | A2、A3、A6 | covered | 播放交由 media_kit/libmpv；其余为桌面播放器 UI，非目标 |

# 非目标

- 不移植 `player.html` 的桌面播放器 UI（画质下拉、复制 m3u8／中继 m3u8、打开原站按钮）。
- 不使用 WebView/iframe 内嵌 missav 原站页面；不建应用内本地中继（Q1-B）。
- 不做 seek 缩略图抓取、预取或缓存；不做番号批量抓取、后台预解析。
- 不改变预告片播放与剧照查看的既有行为（除入口位置与标识、区块标题与显示条件外）。
- 不引入播放历史/断点续播/下载离线观看。
- 不实现 WAF 回退方案（本地中继/libcurl）；若真机验证发现 libmpv 无法直连，另行评估。

# 验收示例

- A1: 影片详情页「正片 / 预告片 / 剧照」区横向列表最前两个位置依次为「正片」入口与「预告片」入口；两个卡片上均有可见文本「正片」「预告片」；预告片入口点击行为、剧照缩略图与查看器行为不变。
- A2: 点击「正片」入口进入全屏播放页；页面先展示解析中状态，解析成功取得 surrit 播放列表后自动开始播放正片（画面与进度推进）；播放页保留返回入口与既有手势操作层。
- A3: 番号在 missav 不存在或页面无法解析出播放列表时，播放页显示失败原因与「重试」按钮；点击重试重新解析，成功后进入播放。
- A4: 解析请求（missav 页面）注入浏览器 UA 与 Accept-Language；播放请求（surrit）注入 Referer `https://missav.live/ja/` 与浏览器 UA（可单测/代码审查验证请求构造）。
- A5: packer 解码与番号规范化可用于真实页面形态：radix 16 与 radix 62 的 packer 均可解出 surrit UUID；无 packer 时以 `surrit.com/{uuid}/playlist.m3u8` 正则兜底；完整 missav 链接与纯番号（含大小写、空格）均规范化为正确番号（单测，含真实页面片段 fixture）。
- A6: 退出播放页后播放器被释放、不再拉流（在途请求停止）；解析中的在途请求在退出后不启动播放、不写页面状态；再次进入可重新解析并播放。
- A7: 无预告片且无剧照的影片上，区块仍显示且包含正片入口（Q3-A），不崩溃、无空指针。
- A8: 既有行为回归：预告片播放入口、剧照查看器、详情页其他区块（演员、类别、磁链等）不受影响。

# 约束与不变量

- 反爬约束来自来源实验结论（S3/S8）：surrit 页面与 CDN 按客户端指纹筛选，且请求要求 missav Referer；实现必须保证 Referer 注入与「能过 WAF 的客户端选型」（页面用 Cronet；流由 libmpv 直连，真机验证）。
- 不采用 WebView/iframe 内嵌原站（S4）。
- 解析失败按自然失败处理并允许重试（S7）；不做自动重试循环与批量抓取。
- 播放复用现有 `MoviePreviewScreen` 操作层与清理路径；预告片路径的既有行为与文案不变（仅新增正片来源的文案）。
- 解析失败不落盘缓存；播放不写磁盘缓存（流播）。
- 依赖与构建：`cronet_http` 以 embedded Cronet 为准（`--dart-define=cronetHttpNoPlay=true`），保证无 GMS 设备可用；测试环境不实例化 Cronet（HTTP 客户端注入替身）。
- 文本中文硬编码、Material 3；遵循项目既有 lint 与测试约定。

# 决策

- D1（用户确认，工作区）：本 change 使用 worktree 隔离（`.worktrees/missav-online-playback`，change 分支基于 master）。
- D2（Agent 决定）：播放页复用 `MoviePreviewScreen` 体系（操作层、清理、错误重试），不新建第二套播放器；正片与预告片共用同一播放页与手势层。
- D3（Agent 决定）：解析与取流组件置于 `lib/features/movie_detail/`（`features` 内聚，`core` 不引入 missav 专有概念）。
- D4（Agent 决定）：番号规范化复用来源算法（大小写、空白、完整链接容错，S12），不新增番号格式猜测。
- D5（Agent 决定）：区块标题调整为「正片 / 预告片 / 剧照」；正片入口卡与预告片入口卡同构（封面图 + 中央播放图标 + 文本标识），正片入口用 `coverUrl`。
- D6（用户确认 Q1-B）：取流架构为「播放器直连 surrit（media_kit 携带 Referer）+ 页面解析走 Cronet」；不建应用内中继、不嵌入 libcurl。已知风险：Android libmpv 的 ffmpeg TLS 栈能否过 WAF 需真机验证（本机 ffmpeg 构建实测 403）；未过则另行评估回退方案。
- D7（用户确认 Q2-A）：解析在播放页内进行；点击即进播放页，页内展示解析中/失败/重试；失败可原地重试。
- D8（用户确认 Q3-A）：正片入口恒定显示；区块显示条件放宽为始终显示（无预告片/剧照的影片也出现区块）。
- D9（用户确认 Q4-A）：正片入口卡与预告片入口卡视觉同构（同一封面图 + 中心播放图标 + 「正片」/「预告片」文本标识），靠标识区分。
- D10（Agent 决定，承 D6）：Cronet 采用 embedded 变体（不依赖 Google Play 服务），CI 构建命令携带 `--dart-define=cronetHttpNoPlay=true`；约定写入 `RULES.md`。
- D11（Agent 决定）：Spec 划分——新增 capability `missav-playback`（解析管线、播放、失败重试、退出清理、构建约束）；`movie-detail-stills` 补充播放入口层（正片/预告片标识与顺序、区块恒定显示、标题）；不动 `movie-preview-controls` / `movie-preview-operations`（预告片路径行为不变）。

# Open questions

（当前无——Q1–Q4 已由用户确认，结论见决策 D6–D9。设备侧真机验证为已知限制，见验证预期，不阻塞 Shape。）

# 验证预期

- `flutter analyze --no-pub` 零新增告警；`flutter test` 全量通过。
- 新增单测：packer 解码（radix 16/62 样本 + 转义）、UUID 正则兜底、番号规范化（完整链接/纯番号/大小写/空格）、请求构造（页面 UA/Accept-Language、播放 Referer/UA）、解析失败信息、退出后不启动播放。
- 新增/调整 widget 测试：区块标题与入口顺序（正片在预告片前）、两个入口文本标识与语义/Key、点击正片入口进入播放页、解析中/失败/重试状态流转、无预告片/剧照影片的入口可见性、退出释放。
- 既有 `movie_detail`、`movie_preview` 相关测试保持通过（如有签名调整则同步最小更新）。
- 构建检查：本地 `flutter build apk --debug --dart-define=cronetHttpNoPlay=true` 编译通过（验证 cronet_http 集成与 Gradle 依赖解析）；CI workflow 命令含该 define。
- 设备侧人工验证（本机无法闭环、列为已知限制）：在可访问 missav 的 Android 设备上确认「解析 → 播放 → 退出清理」真实链路与 libmpv 直连可行性；结果由用户确认。
