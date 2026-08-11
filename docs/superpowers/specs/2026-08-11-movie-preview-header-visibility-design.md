# 预告片顶部栏与 Chewie 控制层同步显隐设计

## 目标

预告片正常播放时，页面顶部的返回按钮和影片标题必须与 Chewie Material
原生控制层使用同一可见状态：

- Chewie 控制层显示时，顶部栏显示；
- Chewie 控制层播放中自动隐藏时，顶部栏同时隐藏；
- 单击画面重新显示 Chewie 控制层时，顶部栏同时显示；
- 顶部栏隐藏后不可点击，也不暴露无效的辅助功能语义。

本设计是
`docs/superpowers/specs/2026-08-11-movie-preview-chewie-refactor-design.md`
的增量修订，只改变正常播放状态的顶部栏归属和显隐。详情入口、路由、横屏、
wakelock、双击播放/暂停、长按临时 `2.0×`、媒体错误、重试和资源清理契约保持
不变。

## 已确认交互

隐藏的是整个顶部栏：

- 返回按钮；
- 单行影片标题。

加载和错误状态没有 Chewie 原生控制层，因此顶部栏始终显示，确保用户随时可以
返回详情页。

正常播放时沿用 Chewie `1.13.1` 的现有行为：

- 初始化后显示控制层；
- 播放中约 3 秒自动隐藏；
- 单击画面切换控制层显示状态；
- 暂停、拖动或 Chewie 认为需要展示操作界面时，顶部栏跟随原生控制层显示。

不新增独立的标题计时器，也不让外层 `GestureDetector` 注册 `onTap`。

## 方案比较

### 方案一：组合原生 MaterialControls 与顶部栏

在 Chewie 的 `customControls` 插槽中放入一个组合 widget：

```text
Stack
├── MaterialControls
└── 顶部栏
    ├── 返回按钮
    └── 影片标题
```

组合 widget 读取 Chewie 当前实例使用的同一个 controls notifier。原生
`MaterialControls` 继续负责点击命中区、播放按钮、进度条、音量、缓冲和 3 秒
自动隐藏；顶部栏只消费其可见状态。

优点：

- 顶部栏与原生控制层精确同步；
- 不复制 Chewie 的计时器、暂停、拖动或缓冲状态机；
- 不改变双击和长按手势层。

代价：

- Chewie `1.13.1` 没有单独公开 controls visibility 回调，需要从导出的
  `ChewieState` 获取其 notifier；
- 该行为必须由回归测试保护，未来升级 Chewie 时需要重新核验。

### 方案二：应用自行镜像控制层状态

页面自行维护 3 秒计时器和单击状态。

优点是完全不读取 Chewie 状态；缺点是暂停、拖动、缓冲、初始化和原生控制按钮
都可能让两套状态机失步，因此不采用。

### 方案三：维护 Chewie 分支

修改 Chewie 以公开 controls visibility API。

接口最清晰，但需要维护依赖分支和升级补丁；本需求只有一个顶部栏消费者，成本
明显过高，因此不采用。

## 选定架构

采用方案一。

### MoviePreviewChewieControls

新增 feature 私有 widget `MoviePreviewChewieControls`，职责只有：

1. 原样渲染 Chewie 的 `MaterialControls`；
2. 从祖先 `ChewieState` 读取同一 controls notifier；
3. 根据 `hideStuff` 控制顶部栏透明度、点击和语义；
4. 不创建任何计时器，不发送播放、暂停、seek 或倍速命令。

该 widget 不直接导入 `package:chewie/src/...` 内部路径。它只依赖
`package:chewie/chewie.dart` 已导出的 `ChewieState`、`MaterialControls` 和
Flutter 的 `ChangeNotifier` 接口。

若构建上下文中意外找不到 `ChewieState`，顶部栏采用可见兜底，保证返回入口不会
因依赖结构变化而消失；聚焦测试必须覆盖正常 Chewie 子树中的同步行为。

### MoviePreviewHeader

现有 `MoviePreviewHeader` 从页面文件移入 movie-detail widgets 层，供两处复用：

- 正常播放：由 `MoviePreviewChewieControls` 管理显隐；
- 加载/错误：由 `MoviePreviewPage` 直接渲染并保持可见。

顶部栏仍使用 `SafeArea`、`返回` tooltip、单行省略标题和
`Semantics(header: true)`。

### Chewie 播放适配器

`ChewieMoviePreviewPlayback` 增加可选 `customControls` 参数，并把它传给
`ChewieController`。其余固定配置不变：

- 继续使用 Chewie Material 原生 `MaterialControls`；
- `hideControlsTimer` 仍为 3 秒；
- 不启用 Chewie 全屏路由或倍速菜单；
- 初始化、状态映射、播放命令和释放顺序不变。

页面默认创建 playback 时传入 `MoviePreviewChewieControls`。测试注入的
`MoviePreviewPlaybackFactory` 签名保持 `MoviePreviewPlayback Function(Uri)`，
避免影响现有页面生命周期 fake。

## 对 customControls 原设计约束的修订

原 Chewie 重构设计禁止使用 `customControls`，目的是避免重新实现旧的自定义播放
按钮、Slider、时间文本和自动隐藏状态机。

本设计作一个窄化例外：

- `customControls` 只能用于组合 Chewie 自带的 `MaterialControls` 和顶部栏；
- 不得复制、修改或替换 Chewie 的播放按钮、进度条、时间、音量、缓冲和显隐计时；
- 不得重新引入已删除的 `MoviePreviewControls`。

因此用户实际操作的播放控制仍是 Chewie Material 原生控制层。

## 动画、点击与辅助功能

顶部栏使用与 Chewie MaterialControls 相同的 250ms opacity 动画：

- 显示状态：`opacity = 1.0`；
- 隐藏状态：`opacity = 0.0`；
- 隐藏时 `IgnorePointer(ignoring: true)`；
- 隐藏时排除返回按钮和标题语义。

顶部栏不增加背景点击层。画面单击继续由 Chewie 原生 hit area 处理，外层
`MoviePreviewGestureLayer` 仍只注册双击和长按系列回调。

## 页面状态

### 正常播放

```text
MoviePreviewGestureLayer
└── Chewie
    └── MoviePreviewChewieControls
        ├── MaterialControls
        └── Animated top header
```

页面不再在 Chewie 外部常驻叠加顶部栏。

### 加载和错误

继续使用现有页面级状态壳：

```text
Stack
├── 加载进度或“预告片播放失败 / 重试”
└── SafeArea 顶部栏（始终显示）
```

媒体错误切换到页面错误壳后，Chewie 子树和同步顶部栏一起卸载。

## 测试策略

### Chewie 控制组合 widget

- 初始化显示控制层后，顶部栏 opacity 为 `1.0`；
- 播放中经过 Chewie 的 3 秒隐藏计时，原生控制层进入隐藏状态，顶部栏 opacity
  同步为 `0.0`；
- 单击画面重新显示原生控制层时，顶部栏同步恢复为 `1.0`；
- 隐藏状态点击顶部返回区域不会触发 `onBack`；
- 隐藏状态不暴露返回按钮和标题语义；
- 未找到 ChewieState 时顶部栏保持可见兜底。

测试必须驱动真实 Chewie `MaterialControls` 和 notifier 行为，不能只调用应用自行
定义的 visibility callback。

### 播放适配器

- 页面提供的组合 controls 被传入 `ChewieController.customControls`；
- 未提供时继续使用 Chewie 默认 AdaptiveControls；
- 其余固定配置和 dispose 测试继续通过。

### 页面回归

- 正常播放页面不再在 Chewie 外部渲染第二份常驻顶部栏；
- 加载、非法 URL、初始化失败、媒体错误仍始终显示顶部栏；
- 返回、重试、双击、长按、横屏、wakelock 和 session lifecycle 测试继续通过。

最后运行新增聚焦测试、全部预告片测试、详情与路由回归、`flutter analyze` 和完整
`flutter test`；重新构建 Debug APK 并覆盖安装到 Android 模拟器。

## 非目标

- 不调整 Chewie 底部控制栏的样式或布局；
- 不修改 3 秒隐藏时间；
- 不增加标题独立显示开关；
- 不让返回按钮在控制层隐藏时保持可见；
- 不修改加载页或错误页的顶部栏可见策略；
- 不升级 Chewie、video_player、wakelock_plus 或项目 SDK 下限。
