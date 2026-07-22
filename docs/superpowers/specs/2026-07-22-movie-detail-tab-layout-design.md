# 影片详情 Tabs 重排设计

## 目标

压缩影片详情页操作区和类别区，将 Tabs 移到封面正下方，并把详情内容重新组织进四个无 Card 外框的 Tab。

## 已确认需求

- 缩小“想看”“看过”“存入清单”三个操作按钮。
- 缩小详情页类别标题、标签、标签间距和区域间距。
- Tabs 紧接在封面图下方。
- Tabs 外层不使用 Card 包裹。
- Tabs 顺序固定为“基本信息”“磁链下载”“短评”“相关清单”。
- “基本信息”包含信息卡、类别、演员、剧照、“TA还出演过”和“你可能也喜欢”。
- 浏览基本信息长内容时封面可以向上滚走，Tabs 吸顶。
- 保留 TabBarView 的点击切换和横向滑动交互。

## 页面结构

详情页保留现有 Scaffold AppBar，body 改为 `DefaultTabController` 包裹的 `NestedScrollView`：

1. Header 第一段为现有影片封面。
2. Header 第二段为 pinned `SliverPersistentHeader`，内部直接展示 TabBar。
3. NestedScrollView body 为四页 TabBarView。

封面随外层滚动离开视口。TabBar 到达 AppBar 下方后吸顶，并使用主题 surface 背景和底部分隔线，避免内容透出。TabBar 本身及其内容区域不使用 Card 外框。

## Tab 内容

### 基本信息

基本信息页使用纵向 ListView，按以下顺序组合现有模块：

1. 信息卡
2. 类别
3. 演员
4. 预告片 / 剧照
5. TA还出演过
6. 你可能也喜欢

没有数据的演员、剧照或推荐模块继续按现有条件隐藏。信息卡保留现有 Card 外观；“Tabs 不使用 Card”仅约束 Tabs 容器，不移除信息卡自身的视觉层级。

### 磁链下载

使用现有磁链列表。空数据时展示“暂无磁链”。

### 短评

使用现有短评列表。空数据时展示“暂无短评”。

### 相关清单

保留现有“相关清单”占位内容，不在本次新增清单接口或交互。

## 紧凑样式

### 操作按钮

- 保持 FilledButton 视觉语义和现有操作文案。
- 最小高度设为 32。
- 横向 padding 缩小为 12。
- 使用 `VisualDensity.compact` 和 `labelMedium` 字体。
- 保持三个按钮的 8 像素横向间距，并允许窄屏换行。

### 类别

- “类别:”使用 `bodyMedium` 加粗，不再使用 `titleMedium`。
- 标题顶部对齐间距缩小。
- 标签使用紧凑视觉密度、shrinkWrap 点击目标和 `labelSmall` 字体。
- 标签横纵间距缩小为 4。
- 紧凑设置仅用于影片详情页，不改变其他页面的 TagChip 默认样式。

## 组件边界

- `_MovieHero`：继续只负责封面。
- `_MovieInfoCard`：继续负责元数据、评分、操作按钮和统计，内部改为紧凑按钮布局。
- `_CategorySection`：增加详情页专用紧凑渲染。
- `_BasicInfoTab`：新增组合组件，负责基本信息内各模块的顺序和条件显示。
- `_MovieDetailTabs`：新增 TabBar、吸顶 header 和 TabBarView 组织逻辑。
- `_AuxiliaryTabs`：被 `_MovieDetailTabs` 取代，不保留 Card 和固定 320 高度结构。

本次不拆分详情页到更多源文件，以控制重构范围；新增私有组件继续放在现有 screen 文件中。

## 数据流与异常处理

- 继续使用当前页面已加载的 detail、magnets、reviews 和 mayAlsoLike 数据。
- 不新增网络请求，不修改附属接口失败不影响主详情的现有策略。
- 空数据 Tab 显示现有空状态，基本信息中的空模块隐藏。
- 内外层滚动遵循 NestedScrollView 协调机制，Tab 内列表不使用额外固定高度 Card。

## 测试与验收

### 自动化测试

- 验证四个 Tab 文案及顺序。
- 验证 TabBar 位于封面 header 后并使用 pinned header。
- 验证 Tabs 不存在 Card 祖先。
- 验证基本信息初始页包含番号、类别、演员、剧照和两个推荐区块。
- 验证操作按钮使用 32 高的紧凑 ButtonStyle。
- 验证详情类别 TagChip 使用紧凑模式。
- 验证切换磁链、短评和相关清单后的内容。
- 验证 390×844 视口滚动无 RenderFlex overflow 或其他异常。
- 运行相关测试、完整 `flutter test` 和 `dart analyze`。

### ADB 验收

1. 进入含演员、剧照和推荐数据的详情页。
2. 确认 Tabs 紧贴封面且没有 Card 外框。
3. 向上滚动基本信息，确认封面滚走且 Tabs 吸顶。
4. 确认操作按钮与类别区域明显更紧凑且无溢出。
5. 依次切换四个 Tab，确认内容和空状态正确。
6. 检查日志中不存在 Flutter overflow、未处理异常或崩溃。

## 非目标

- 不修改影片数据模型和接口。
- 不实现操作按钮业务逻辑。
- 不实现相关清单数据源。
- 不修改演员、剧照或推荐卡片样式。
- 不改变影片图片模糊功能及其设置。

## 成功标准

- 封面可滚走，四个无 Card 外框的 Tabs 在封面下方并可吸顶。
- 基本信息完整包含已确认的六类内容且顺序正确。
- 操作按钮和类别区域更紧凑，窄屏无溢出。
- 其他三个 Tab 保持原有内容和空状态。
- 自动化测试、静态分析和 ADB 验收全部通过。
