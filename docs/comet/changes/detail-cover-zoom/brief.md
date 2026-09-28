# Outcome

影片详情页顶部封面大图（`MovieDetailHero`）支持点击放大查看：点击后打开与剧照一致的全屏大图查看器（`ImageGalleryViewer`），支持缩放、拖动与关闭；模糊开关（`blurMovieImages`）行为与剧照查看器一致。

# Scope

- 影片详情页顶部封面大图（`MovieDetailHero`）：新增点击放大入口；放大查看器复用剧照所用的 `ImageGalleryViewer`，仅显示封面一张。

## Source coverage

无来源文档：需求由用户以文字直接提出，不进入源文档完整覆盖模式。

# Non-goals

- 不改变剧照区（「预告片 / 剧照」`MovieScreenshotSection`）的现有行为：缩略图显示与宽高比记忆、点击打开查看器并定位对应剧照、预告片封面为播放入口。
- 不改变图片模糊开关（`blurMovieImages`）的作用范围（现状：开启时全部图片模糊，包括封面与剧照）。
- 不改变顶部封面图本身的布局、高度 clamp、占位底色与加载行为。

# Acceptance examples

- A1: 详情页已加载且封面 URL 非空时，点击顶部封面大图打开全屏查看器，仅显示封面一张（计数 1 / 1），可关闭返回详情页。
- A2: 放大后的查看器交互与剧照查看器一致：黑底全屏、双指缩放（初始 contained、最小 contained、最大 4x）、拖动平移。
- A3: 模糊开关开启时放大后的封面同样模糊；关闭开关后放大查看为清晰图（与剧照查看器一致，无特判）。
- A4: 封面入口为按钮语义，标签「查看《影片标题》封面大图」，Key 为 `movie-detail-cover`；查看器沿用现有 Key（`image-gallery-viewer` 等）与语义。
- A5: 剧照区回归不变：剧照缩略图点击仍打开查看器并定位对应剧照，预告片封面仍是播放入口，语义与 Key 均不变。

# Constraints and invariants

- 复用 `ImageGalleryViewer`，不新增第三种查看器实现。
- 封面放大沿用 `CachedImage` 现有模糊逻辑，不做特判。
- 封面自身布局不变：宽度全宽，高度 `maxWidth / 1.45` clamp(220, 360)，底色 `surfaceContainerHighest`，`BoxFit.cover` 填充，加载、缓存、解密与 fallback 资产行为不变。
- `coverUrl` 为空（trim 后）时不提供点击入口，封面保持纯展示。
- 入口无障碍语义：可聚焦按钮并带语义标签；查看器内部沿用其现有语义与 Key。
- 现有剧照区规格 `movie-detail-stills` 的行为不受影响。

# Decisions

- D1（用户确认 Q1）：放大查看器仅显示封面一张（计数 1 / 1），不含剧照；「封面 + 全部剧照连贯浏览」方案被否决。
- D2（Agent 决定）：查看器实现复用 `ImageGalleryViewer`，以 `showDialog(useSafeArea: false)` 打开，与剧照打开方式一致。
- D3（Agent 决定）：入口语义 label 取「查看《title》封面大图」（沿用剧照 label 的中文表述风格），Key 取 `movie-detail-cover`（与 `movie-detail-preview`、`movie-detail-screenshot-N` 同风格）。
- D4（Agent 决定）：新建 capability 规格 `movie-detail-cover` 描述顶部封面行为；不并入 `movie-detail-stills`（该规格约束剧照区，顶部封面是页面上的独立区域）。

# Open questions

（当前无——Q1 已由用户确认：仅封面一张。）

# Verification expectations

- `flutter analyze` 无新增告警。
- 新增/调整 widget 测试覆盖：点击封面打开查看器、入口语义与 Key、查看器内容构成（依 Q1 结论）。
- 现有剧照区与详情页相关测试保持通过。
