---
generated_from_state_version: 12
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 2
- 验证器尝试次数: 1
- 完成时间: 2026-10-16T05:37:38.356Z
- 摘要: 21/21 全部通过（iteration 2，candidate 4d44089e）。本轮修复的两点均在本机独立复现：（1）媒体不可达时起播不再永久加载——play() 挂起被 20s 起播上界拦住，13:24:58.165 日志「session-init failed: TimeoutException after 0:00:20.000000」并进入「在线播放失败」+「重试」，点击重试重新走解析与播放；（2）Android 走 vo=mediacodec_embed + hwdec=mediacodec 的 MediaCodec 直渲染（无 EGL 依赖），模拟器上「正片」（出画、进度 00:19→00:50、seek 到 02:41 后继续至 03:00）与「预告片」（00:28→00:36 / 01:00）均成功出真实画面；设备侧另闭环：断网播放 → mpv ffmpeg/error 进日志 + 失败态可重试 → 恢复后重试成功出画；断网解析失败 → 失败态 → 恢复后重试成功出画；退出播放后 mpv 线程与 CPU 归零、再次进入可重新解析播放；核查记录与工作区一致（analyze 0 告警、992 tests passed，本人独立复跑结果相同，新增起播时序/上界与日志转发测试单独运行通过）。遗留风险主要是「挂起播放器的资源未真正回收」（僵尸 mpv 线程持续 CPU，仅 force-stop 能清）与「20s 上界未覆盖解析/initialize 阶段」，另有真机未回归、起播约 +1s 稳定窗、日志无速率限制等，详见 risks。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | 模拟器上播放「正片」：出现真实画面（非全黑），进度推进，拖动到任意时间点后继续播放出画面。 | 本机独立复现（emulator-5554，候选 debug 0.14.0-alpha，pid 920）：VOV-055「正片」出真实画面（MISSV.com 水印可见），进度 00:19→00:36→00:50 实时推进；横向拖动 seek 到 02:41 后继续出画（03:00）。截图 /private/tmp/v2_a1_t8.png、v2_a1_ctrl2.png、v2_seek_after.png、v2_seek_after2.png。 |
| A2 | passed | brief.md | 模拟器上播放「预告片」：出现真实画面，进度推进。 | 本轮已闭环（iteration 1 该场景受阻）：本机复现 VOV-055「预告片」出真实画面，时长 01:00，进度 00:28→00:36 推进（截图 /private/tmp/v2_a2_ctrl1.png、v2_a2_ctrl2.png）；日志 13:23:41.900 VideoOutput 已绑定 surface（wid 非 0）且无 view-ready 超时。iteration 1 出现的「预告片永久加载态」本轮未复现（同时起播阶段已有 20s 上界兜底）。 |
| A3 | passed | brief.md | 起播时序：视频输出在播放页画面输出（surface）就绪并绑定后才开始播放，不出现「先起播、后中途切换视频输出」造成的卡死或黑屏。 | 代码：initialize → session.isInitialized=true + setState 挂载画面 → waitUntilViewReady（surface id 就绪 + 1s 稳定窗，等待上限 5s）→ play；设备日志显示 VideoOutput wid 绑定（13:24:40.592 / 13:31:08.592 / 13:35:26.106）先于画面出现；本轮新增 widget 测试「起播前先挂载播放画面并等待画面输出就绪」由本人单独运行通过（断言 play 不早于 view-ready、操作层不提前出现）。 |
| A4 | passed | brief.md | Android 视频渲染使用 MediaCodec 直接渲染输出，不依赖 GL/EGL 上下文（模拟器上 GL 上下文不可用也能出画）。 | moviePreviewVideoControllerConfiguration(isAndroid:true) 返回 vo=mediacodec_embed + hwdec=mediacodec，非 Android 返回默认（本人单独运行该单测通过）；media_kit_video-2.0.1 android_video_controller/real.dart 确认 configuration.vo/hwdec 透传 mpv，且对 vo=mediacodec_embed 额外补 vid=auto；设备端（gfxstream+SwiftShader，GL/EGL 不可用）出画，全程无 EGL/GLES/vo=gpu fatal 日志。 |
| A5 | passed | brief.md | 播放链路出现 error/fatal 级信息（视频输出初始化失败、网络失败、解码失败等）时，设备日志包含其 prefix、级别与文本，可定位失败环节。 | 设备实测（本人独立抓取 /private/tmp/v2_evidence_logcat_final.txt，18800+ 行）：movie_preview mpv[ffmpeg/error] tcp: Failed to resolve hostname surrit.com: No address associated with hostname（13:32:55 断网播放时真实网络失败）、movie_preview mpv[lavf/error] Failed to create file cache.、movie_preview mpv[media_kit/error] ...，格式为 mpv[prefix/level] text；media_kit 1.2.6 源码确认 MPV_EVENT_LOG_MESSAGE 全量转发（error 及更高，含 fatal）。 |
| A6 | passed | brief.md | 既有测试全部通过；新增测试覆盖渲染配置、起播时序与日志转发；`flutter analyze` 零告警。 | 本人独立复跑：flutter analyze --no-pub → 「No issues found!」；flutter test --no-pub → 「+992: All tests passed!」；新增两个 widget 测试单独运行亦通过（「起播长时间无响应时按播放失败呈现并可重试」「起播前先挂载播放画面并等待画面输出就绪」），movie_preview_playback_test 18 项全通过。Runtime 检查记录（analyze/test，13:13:39–13:14:20）与当前工作区一致：源文件最后修改 12:10–12:59，早于检查执行；新增测试覆盖渲染配置、日志格式化/转发、view-ready 与稳定窗、起播时序与 20s 起播上界。 |
| A7 | passed | specs/missav-playback/spec.md | 解析成功得到播放地址 Given 番号在 MissAV 有对应影片页且页面包含 packer 混淆的 surrit 地址 When 触发解析 Then 返回 `https://surrit.com/{uuid}/playlist.m3u8` 形态的播放地址与 Referer/UA 请求头 | missav_stream_resolver_test「解析成功返回播放地址与 Referer/UA 请求头」随全量测试通过；设备端解析请求 uri=https://missav.live/ja/vov-055（番号小写、语言段正确），解析成功后直连 surrit 播放出画（13:31:05.981 创建播放器）。 |
| A8 | passed | specs/missav-playback/spec.md | packer 解码支持两种 radix 与转义 Given 页面含 radix 16 或 radix 62 的 packer 混淆脚本（含 `\x` / `\u` 转义） When 执行解码 Then 解出的文本包含正确的 surrit UUID，不因转义导致解码失败 | missav_page_parser_test 的 radix 16 / radix 62 packer 与 \x/\u 转义用例随全量测试（992）通过。 |
| A9 | passed | specs/missav-playback/spec.md | 无 packer 时正则兜底 Given 页面未使用 packer 混淆但含明文 `surrit.com/{uuid}/playlist.m3u8` When 触发解析 Then 仍能提取到播放地址 | missav_page_parser_test 无 packer 时明文 surrit 兜底用例随全量测试通过。 |
| A10 | passed | specs/missav-playback/spec.md | 番号规范化容错 Given 输入为完整 missav 链接（含语言段与路径）或带空格/大小写差异的纯番号 When 执行规范化 Then 输出小写、无空白的番号并用于页面请求 | missav_page_parser_test/lib 规范化用例（纯番号小写、去空白、完整链接取末段）随全量测试通过；设备日志中请求路径与失败 uri 均为 /ja/vov-055。 |
| A11 | passed | specs/missav-playback/spec.md | 解析失败返回可读原因 Given 番号不存在、页面请求非 200 或页面中找不到 surrit 地址 When 触发解析 Then 解析以失败结束并给出可展示的原因，播放页进入失败状态 | 本机复现：断网（飞行模式）进入「正片」→ 页面显示「在线播放失败」+「重试」（/private/tmp/v2_offline_t12.png）；日志 13:34:45 movie_preview online-resolve failed: 页面请求失败：NetworkClientException: ... net::ERR_PROXY_CONNECTION_FAILED ... uri=https://missav.live/ja/vov-055（可读原因）。 |
| A12 | passed | specs/missav-playback/spec.md | 解析成功后自动开始播放 Given 解析已成功返回播放地址与请求头 When 播放页就绪 Then 自动开始播放（画面与进度推进），操作层可用 | 设备：解析完成后无需操作即自动出画，操作层可用（标题/暂停/进度/seek 均生效）；widget 测试「在线来源：先显示解析中，解析成功后自动播放解析地址」随全量测试通过。 |
| A13 | passed | specs/missav-playback/spec.md | 播放请求携带 Referer Given 在线正片播放已开始 When 检查播放器对 surrit 的请求构造 Then 请求携带 `Referer: https://missav.live/ja/` 与浏览器 UA | resolver 输出 httpHeaders（Referer: https://missav.live/ja/ + 浏览器 UA）经 Media 注入播放器（单测「httpHeaders 注入到打开的 Media（在线正片 Referer）」随全量测试通过）；设备端 surrit 直连播放成功（该 CDN 强制 Referer 白名单，缺失即拒绝），说明播放请求头生效。 |
| A14 | passed | specs/missav-playback/spec.md | 画面输出就绪后起播 Given 播放地址已就绪且播放页开始建立视频画面输出 When 播放器开始播放 Then 视频输出已绑定到播放页的画面输出后再起播，画面可见（非全黑）且进度推进 | 与 A1/A3 同源：画面可见（非全黑）且进度实时推进（00:19→00:36→00:50，seek 后 02:41→03:00 继续出画）；play 在 waitUntilViewReady 之后调用（widget 测试断言），不存在「先起播、后中途切换视频输出」。 |
| A15 | passed | specs/missav-playback/spec.md | MediaCodec 直渲染路径 Given Android 环境（含 GL/EGL 不可用的模拟器） When 初始化播放器渲染 Then 使用 MediaCodec 直接渲染输出到播放页画面，经 MediaCodec 硬件解码播放，不需要 GL 上下文 | 与 A4 同源：设备（模拟器 GL 上下文不可用）经 vo=mediacodec_embed + hwdec=mediacodec 出画，无 EGL 失败；media_kit_video 源码确认该配置走 MediaCodec 直接渲染到 surface。 |
| A16 | passed | specs/missav-playback/spec.md | 解析失败可原地重试恢复 Given 首次解析失败（例如网络不可达或番号不存在） When 查看播放页 Then 显示失败状态与「重试」；条件恢复后点击重试，解析成功并开始播放 | 本机复现闭环：断网进入 → 「在线播放失败」+「重试」→ 恢复网络（airplane_mode_on=0，proxy=10.0.2.2:7890）→ 点击「重试」→ 重新解析成功并播放出真实画面（13:35:23 重试 → 13:35:26 surface 绑定；截图 /private/tmp/v2_a16_retry_t22.png）。 |
| A17 | passed | specs/missav-playback/spec.md | 播放失败可重试 Given 解析成功但播放器报错（例如 CDN 拒绝） When 查看播放页 Then 显示失败状态与「重试」，点击重试重新走解析与播放 | 本机复现两条腿：(1) 媒体不可达时起播挂起 → 13:24:58.165 日志「movie_preview session-init failed: TimeoutException after 0:00:20.000000」（起播上界精确 20s 触发）→ 页面显示「在线播放失败」+「重试」（点击处 /private/tmp/v2_a17_t24.png），点击后重新走解析/播放；(2) 播放中断网 → mpv ffmpeg/error → 页面「在线播放失败」+「重试」（v2_net_off_t42.png）→ 恢复网络点重试 → 重新解析并出画（v2_retry2_t26.png）。新增 widget 测试「起播长时间无响应时按播放失败呈现并可重试」本人单独运行通过。 |
| A18 | passed | specs/missav-playback/spec.md | 播放失败原因写入日志 Given 播放器在播放链路报出 error 或 fatal 级信息（例如视频输出初始化失败、网络失败、解码失败） When 查看设备日志 Then 日志包含该信息的 prefix、级别与文本，可据此定位失败环节 | 同 A5：设备日志含 prefix、级别与文本（movie_preview mpv[prefix/level] text）；代码核对 _onLog 仅写 logSink（debugPrint），不改变播放状态与用户可见文案（失败文案仍统一「在线播放失败」）。 |
| A19 | passed | specs/missav-playback/spec.md | 退出播放页停止取流 Given 在线正片正在播放 When 退出播放页 Then 播放器被释放、无继续拉流；再次进入可重新解析并播放 | 本机复现：正常播放中进程 2 个 mpv 线程、CPU 82%、443 连接 7 条；按返回退出后 10s 内 mpv 线程 0、CPU 0.0%、无 ESTABLISHED 443（仅 TIME_WAIT）；再次进入同一影片可重新解析并出画（13:20:49、13:23:40 预告片、13:35:23 三次均成立）。注：起播挂起（20s 上界触发）场景下的资源残留见 risks[0]。 |
| A20 | passed | specs/missav-playback/spec.md | 解析中退出无副作用 Given 解析请求仍在进行 When 退出播放页 Then 请求完成后不启动播放、不写入页面状态、不崩溃 | widget 测试「在线来源：解析中退出不启动播放且无副作用」随全量测试通过；代码核对解析、初始化、等待画面、play 各阶段均以 _isCurrentGeneration/_isCurrentSession 校验，代际过期走 _detachAndCleanup，无写状态/崩溃路径。 |
| A21 | passed | specs/missav-playback/spec.md | 发布构建携带 embedded Cronet 配置 Given CI 或本地发布构建 When 检查构建命令（workflow / RULES.md） Then 包含 `--dart-define=cronetHttpNoPlay=true`，APK 依赖 cronet-embedded 而非 play-services-cronet | .github/workflows/compile_apk.yml:71 `flutter build apk --split-per-abi --dart-define=cronetHttpNoPlay=true`；RULES.md:15 同步该构建约定；cronet_http-1.10.0/android/build.gradle:67-70 在该 define 为 'true' 时 implementation org.chromium.net:cronet-embedded:143.7445.0，否则 play-services-cronet。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze | analyze --no-pub | . | passed | 0 | 5785 ms |
| flutter test | test --no-pub | . | passed | 0 | 35938 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze --no-pub: passed — No issues found!
- flutter test --no-pub: passed — 992 tests passed
- 模拟器设备实测（emulator-5554，iteration 2 候选 debug 构建）: passed — 在线流出画/进度推进/失败→重试→成功；预告片出画；退出播放页后 0 个 mpv 线程；失败原因出现在设备日志中。
- 旧构建 A/B 对照（预告片 CDN 失败）: passed — 修改前 APK 在同一影片预告片上也失败，确认该失败为环境/CDN 可达性问题，不是本次改动引入。
- 已知限制: 真机（用户设备）未在本机验证：真机「解析成功后提示在线播放失败」的根因需真机日志确认（新构建会把 mpv 失败原因写入日志）。
- 已知限制: 起播前有 1s 稳定窗口（viewBindingSettle），真机起播会相应延迟约 1s；起播阶段另有 20s 上界（超时进入可重试失败态）。
- 已知限制: mpv `video-params.hw-pixelformat` 在 media_kit 1.2.6 + 本片源上未出现，未能用确定性信号替代稳定窗；已改为有界等待（超时继续）。
- 已知限制: 模拟器上部分片源 CDN（如 ygp.blxr5es.com、部分 surrit 分段）在当前网络下会瞬时不可达，导致播放失败；与本改动无关（修改前构建同样失败），失败会呈现并可重试。
- 已知限制: `flutter test` 计划内含既有测试，若仓库既有测试告警会导致检查失败（当前 0 告警、全通过）。

## 阻塞项

_无。_

## 风险与跳过的工作

- 挂起场景下播放器资源未真正释放（本轮新观察，非验收项失败）：媒体不可达触发 20s 起播上界后，重试/退出对卡死播放器的清理只是「有界等待」——日志显示 pause/dispose 各超时 1.5s（13:25:35.257、13:25:36.758 来自 _retry；13:27:44.479、13:27:46.588 来自退出 dispose，均 _runCleanup/_ignoreBoundedCleanup），随后旧 mpv 播放器仍在后台运行：ps -T 3 个 mpv 线程、CPU 23%~26% 持续 >4 分钟，只有 force-stop 才结束。正常成功路径退出无此问题（线程/CPU 立即归零）。建议后续为卡死播放器增加强制回收兜底。
- 20s 上界只覆盖「等待画面就绪 + play」两段；本人观察到一次重试后 >2 分钟无上界的加载态（页面持续「正在解析播放地址…」，期间无新播放器创建、resolver 自带 20s 请求超时也未触发、无 online-resolve/session-init 失败日志），疑似上一枚卡死播放器持续以毫秒级重复输出 mpv 日志造成 Dart 事件循环饥饿（同一毫秒 11+ 条重复 ffmpeg/error）；未能确证。解析/initialize 阶段仍无显式上界，「永久加载态」在极端情况下仍可能出现。
- mpv 日志转发无速率限制：媒体不可达时同一错误在毫秒级重复数十条并写入设备日志，会灌满 logcat 并疑似拖慢事件循环（与 risks[1] 相关）。
- 真机（用户设备）本轮完全未验证：Android 统一改为 vo=mediacodec_embed + hwdec=mediacodec（绕开 media_kit 对模拟器的软解默认），真机渲染/解码路径随之变化，需用户真机回归；真机失败原因现可由新日志定位。
- 起播延迟：画面就绪后固定 wait 1s 稳定窗（上限 5s 画面就绪等待）→ 起播约 +1s，最坏约 +6s 才 play，可能与 iteration 1 记的同类感知问题一致。
- 未解释的交互观察（控件层本轮未改动，低置信度）：横屏进度条下缘单击（1500,1020）曾导致播放页在 ~1.7s 后自动退出（13:19:39 tap → 13:19:41.377 route pop，日志无异常）；改用横向拖动 seek 后完全正常，未能复现该单击行为，暂按 adb 触点落在系统手势区/坐标解释差异处理。
- 既有小瑕疵（本轮未改动，供后续参考）：_seekToProgress 以 overlay 全宽为分母换算进度条点选落点（进度条是 Row 内子布局），点选定位会偏小；已挂载画面但仍在起播等待时状态文本仍显示「正在解析播放地址…」。
- 设备证据为人工 adb 交互（截图/logcat/ps/uiautomator），非自动化回归；候选构建对应关系：APK lastUpdateTime 13:01:08 晚于源文件最后修改 12:59:58，且安装包显示本轮新增行为（起播上界 20s 精确触发、movie_preview mpv[prefix/level] 日志格式、view-ready 等待），确认设备证据属于当前候选。运行后环境已恢复：airplane_mode_on=0、http_proxy=10.0.2.2:7890。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | blocked | A2 | 21 项验收中 20 项通过：核心修复已在本机独立复现并核实——Android 走 vo=mediacodec_embed+hwdec=mediacodec 的 MediaCodec 直渲染（无 EGL/GL 依赖、日志无 EGL fatal）、起播时序为「挂载画面→等 surface 就绪+有界稳定窗→play」、mpv error/fatal 日志已写入设备日志；正片在 emulator-5554 上出画面、进度推进、seek 到任意点后继续出画、退出后 mpv 线程与 CPU 归零、断网/恢复下的解析失败与重试链路可用；Runtime 检查记录与当前工作区一致（analyze 0 告警、991 tests passed，Verifier 追加的定向 movie_detail 检查 65 tests passed）。唯一未通过项为 A2（模拟器预告片出画）：本机三次尝试预告片页均无法加载出画面（停留在加载态且无失败提示），既无法独立复现 Builder 的预告片出画证据，也暴露「媒体未就绪时起播」可能静默挂起的风险，故 verdict=blocked，需真机或后续一轮确认预告片路径。 | 2026-10-16T04:57:42.466Z |
| 1 | 1 | 1 | recovery | — | Verifier 发现真实缺陷：媒体不可达时播放器 play() 长时间不返回，页面永久停在加载态（无失败态、无重试）。已在实现中修复：起播阶段（等待画面就绪 + play）加 20s 上界，超时按播放失败呈现并可重试；并补充单测（play 永不完成 → 20s 后显示失败态与重试）。同时补充本轮设备证据：预告片出画（START-649）、在线流出画（DBER-065，含失败→重试→成功）、退出后 0 个 mpv 线程。 | 2026-10-16T05:13:17.050Z |
| 1 | 2 | 1 | pass | — | 21/21 全部通过（iteration 2，candidate 4d44089e）。本轮修复的两点均在本机独立复现：（1）媒体不可达时起播不再永久加载——play() 挂起被 20s 起播上界拦住，13:24:58.165 日志「session-init failed: TimeoutException after 0:00:20.000000」并进入「在线播放失败」+「重试」，点击重试重新走解析与播放；（2）Android 走 vo=mediacodec_embed + hwdec=mediacodec 的 MediaCodec 直渲染（无 EGL 依赖），模拟器上「正片」（出画、进度 00:19→00:50、seek 到 02:41 后继续至 03:00）与「预告片」（00:28→00:36 / 01:00）均成功出真实画面；设备侧另闭环：断网播放 → mpv ffmpeg/error 进日志 + 失败态可重试 → 恢复后重试成功出画；断网解析失败 → 失败态 → 恢复后重试成功出画；退出播放后 mpv 线程与 CPU 归零、再次进入可重新解析播放；核查记录与工作区一致（analyze 0 告警、992 tests passed，本人独立复跑结果相同，新增起播时序/上界与日志转发测试单独运行通过）。遗留风险主要是「挂起播放器的资源未真正回收」（僵尸 mpv 线程持续 CPU，仅 force-stop 能清）与「20s 上界未覆盖解析/initialize 阶段」，另有真机未回归、起播约 +1s 稳定窗、日志无速率限制等，详见 risks。 | 2026-10-16T05:37:38.356Z |



## 结论

21/21 全部通过（iteration 2，candidate 4d44089e）。本轮修复的两点均在本机独立复现：（1）媒体不可达时起播不再永久加载——play() 挂起被 20s 起播上界拦住，13:24:58.165 日志「session-init failed: TimeoutException after 0:00:20.000000」并进入「在线播放失败」+「重试」，点击重试重新走解析与播放；（2）Android 走 vo=mediacodec_embed + hwdec=mediacodec 的 MediaCodec 直渲染（无 EGL 依赖），模拟器上「正片」（出画、进度 00:19→00:50、seek 到 02:41 后继续至 03:00）与「预告片」（00:28→00:36 / 01:00）均成功出真实画面；设备侧另闭环：断网播放 → mpv ffmpeg/error 进日志 + 失败态可重试 → 恢复后重试成功出画；断网解析失败 → 失败态 → 恢复后重试成功出画；退出播放后 mpv 线程与 CPU 归零、再次进入可重新解析播放；核查记录与工作区一致（analyze 0 告警、992 tests passed，本人独立复跑结果相同，新增起播时序/上界与日志转发测试单独运行通过）。遗留风险主要是「挂起播放器的资源未真正回收」（僵尸 mpv 线程持续 CPU，仅 force-stop 能清）与「20s 上界未覆盖解析/initialize 阶段」，另有真机未回归、起播约 +1s 稳定窗、日志无速率限制等，详见 risks。
