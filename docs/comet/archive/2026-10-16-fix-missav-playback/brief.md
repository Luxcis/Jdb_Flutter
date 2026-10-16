# 目标

修复「正片」在线播放（MissAV）当前的两个失败形态，并让后续失败可定位：

1. 模拟器：解析成功、进度推进、可拖动任意时间点，但视频画面全程黑色（只有音频）。
2. 真机：解析地址完成后播放页提示「在线播放失败」。

本轮调查已确证的事实（模拟器 emulator-5554，arm64/API36，宿主代理 10.0.2.2:7890）：

- 模拟器黑屏根因（用 mpv 原始日志确证）：播放器走 `vo=gpu`（GLES/EGL，渲染到 Flutter SurfaceProducer 表面）时，mpv 无法在该模拟器（gfxstream + SwiftShader）上创建 EGL context：
  `vo/gpu/opengl/fatal: Could not create EGL context for GLES 2.x +!` → `vo/gpu/error: Failed initializing any suitable GPU context!` → `cplayer/fatal: Error opening/initializing the selected video_out (--vo) device.` → `cplayer/info: Video: no video`。
  结果是 mpv 降级为纯音频播放：进度推进、可拖动、无画面。同一模拟器上「预告片」（本地 MP4）同样黑屏，说明与 MissAV 片源无关，是渲染路径问题。
  另外：这些 mpv `fatal` 级日志既没有转发到应用错误状态（media_kit 只转发 level==error 的少数前缀），也没有写入任何日志，所以应用表现为「静默黑屏」。
- 起播时序问题：当前实现在 Video 画面（surface）尚未就绪时就调用 `play()`，mpv 先以 `vo=null` 起播、之后中途切换到目标 vo。
- 修复方向已在模拟器上实验验证有效（临时改动，已还原）：
  `VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec')`（MediaCodec 直接渲染到 surface，不经 EGL）+「先挂载画面、surface 就绪后再起播」——正片与预告片在模拟器上均出现真实画面、进度推进（实测截图为证）。
- 真机失败根因尚未确定：需要真机侧证据。当前实现丢弃了 mpv 的失败原因（`_onError` 不写日志、UI 统一显示「在线播放失败」），因此真机失败原因不可见。

# 范围

- Android 播放器渲染路径与起播时序：让「正片」与「预告片」在模拟器上出画面，且不破坏真机既有行为（方案取舍见 Q2）。
- 播放失败可诊断：把 mpv 的 error/fatal 日志写入设备日志（开发构建可见），使真机失败原因可定位；失败 UI 是否展示具体原因见 Q4。
- 真机失败修复：以真机证据为准（获取方式见 Q3）；本轮先交付「模拟器出画 + 可诊断」，真机问题按证据修复。
- 目录结构

## 目录结构

### 新建

- 暂无（若需要，新增 movie_detail 下的播放配置单元与对应测试文件）。

### 修改

- `lib/features/movie_detail/services/movie_preview_playback.dart`：VideoController 渲染配置、mpv 日志转发、暴露「画面就绪」等待能力。
- `lib/features/movie_detail/screens/movie_preview_screen.dart`：把「挂载画面 → 等待 surface 就绪 → 起播」的时序写进会话初始化（仅在线/预告片共用路径）。
- `test/features/movie_detail/` 下相关测试：覆盖渲染配置选择、日志转发、起播时序。

### 删除

- 无。

### 明确不建

- 不建应用内中继/代理服务；不改解析管线（Cronet 抓页 + packer 解码）；不新增三方依赖（除非结论必需且经用户确认）。

# 非目标

- 不修复模拟器自身图形栈（gfxstream/SwiftShader/EGL 翻译层）。
- 不改动解析地址、Referer/UA 注入与退出清理语义。
- 不新增画质选择、字幕、下载等播放功能。
- 不承诺在无代理/无法访问 MissAV 的网络环境下播放成功。

# 验收示例

- 模拟器上播放「正片」：出现真实画面（非全黑），进度推进，拖动到任意时间点后继续播放出画面。
- 模拟器上播放「预告片」：出现真实画面，进度推进。
- 起播时序：视频输出在播放页画面输出（surface）就绪并绑定后才开始播放，不出现「先起播、后中途切换视频输出」造成的卡死或黑屏。
- Android 视频渲染使用 MediaCodec 直接渲染输出，不依赖 GL/EGL 上下文（模拟器上 GL 上下文不可用也能出画）。
- 播放链路出现 error/fatal 级信息（视频输出初始化失败、网络失败、解码失败等）时，设备日志包含其 prefix、级别与文本，可定位失败环节。
- 既有测试全部通过；新增测试覆盖渲染配置、起播时序与日志转发；`flutter analyze` 零告警。

# 约束与不变量

- 解析与请求头注入（`Referer: https://missav.live/ja/` + 浏览器 UA）保持不变。
- 失败与重试交互保持不变（失败文案是否变化取决于 Q4）。
- 退出播放页仍释放播放器并停止取流；解析中退出无副作用。
- 既有测试（990+）不得回归。

# 决策

- D1（已确证）：模拟器黑屏 = `vo=gpu` 在该模拟器无法创建 EGL context，mpv 降级纯音频。修复必须改变渲染路径（或在模拟器上降级），仅改错误提示无法解决。
- D2（已实验验证）：`vo=mediacodec_embed` + `hwdec=mediacodec` + 「surface 就绪后再起播」可在模拟器上出画面（正片与预告片均验证）。
- D3：本轮包含「失败可诊断」改造（mpv error/fatal 写入日志），因为它不改变用户可见行为且是真机问题定位的前提。
- D4：不引入中继/代理；真机若确为网络路径问题，另行按证据评估（不在本轮预设方案）。
- D5（未获用户答复，按最佳判断采用；用户回归后可调整）：模拟器出画方案取「Android 统一改 MediaCodec 直渲染（mediacodec_embed + hwdec=mediacodec）+ 画面就绪后起播」——模拟器已验证、只维护一条路径、与 mpv-android 默认一致；代价是真机渲染路径随之变化，真机回归由用户确认。
- D6（未获用户答复，按最佳判断采用）：真机失败原因取证先按「可诊断性 + 最可能修复」推进；交付的诊断构建由用户在真机复现（若仍失败，日志给出 mpv 原因）。
- D7（未获用户答复，按最佳判断采用）：失败呈现保持统一文案「在线播放失败」（符合现有规格），原因写入设备日志；不改用户可见文案。
- D8：真机「预告片」是否可播放（区分真机问题是通用渲染还是在线路径专属）作为用户侧信息项，不作为本轮实现在本机可验证的前提。

# Open questions

（本轮无阻塞项：Q1–Q4 已按 D5–D8 采用最佳判断结论。真机回归结果与用户偏好可在验收后回流为新的决策。）

# 验证预期

- 代码级：`flutter analyze` 零告警；`flutter test` 全绿；新增/更新测试覆盖渲染配置选择、mpv 日志转发与起播时序。
- 设备级（模拟器，本机执行，adb 侧命令）：正片与预告片出画面、进度推进、seek 后继续出画；退出后无残留拉流。
- 设备级（真机，用户执行）：正片播放出画面；若失败，新构建日志中应包含 mpv 的 error/fatal 原因（据此进入下一轮修复）。
- 已知限制：真机行为无法在本机复现；本机 ffmpeg/curl 对 CDN 的访问结论会随网络与代理节点漂移，测试前先复核基线。
