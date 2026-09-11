# 目标

影片详情页「预告片 / 剧照」区中的剧照小图缩略图，在预览时根据每张图片的实际宽高比自动缩放显示，避免不同比例的剧照被固定 16:9 格子裁剪。

# 范围

- 现状：`lib/features/movie_detail/widgets/basic_info_sections.dart` 的 `MovieScreenshotSection` 用固定 `AspectRatio(16/9)` 格子 + `MovieScreenshotImage`（默认 `BoxFit.cover`）裁剪填充剧照缩略图；区域高度固定 164。
- 修改目标：剧照缩略图高度统一，宽度按每张图片实际宽高比自适应缩放，完整显示图片；图片尺寸在运行时从图片流获取（Flutter 标准 `ImageStream`/`ImageInfo` 能力，项目当前无先例）。
- 全屏大图查看器 `ImageGalleryViewer`（photo_view contained）已完整显示图片，不在本 change 修改范围内。

# 非目标

- 不改变全屏大图查看器 `ImageGalleryViewer` 的行为。
- 不改变预告片封面缩略图（第一个格子，`MovieCoverImage` cover）的显示方式。
- 不改变 `MovieScreenshotImage` 在影片列表行（`movie_list_tile.dart`，84×56）中的显示方式。
- 不改变图片加载、缓存、解密与模糊设置（`CachedImage`/`JdbImageCacheManager`）的现有逻辑。

# 验收示例

- A1: 剧照缩略图加载完成后按图片实际宽高比缩放显示完整图片，不被裁剪，也没有空隙填充。
- A2: 同一排中不同比例的剧照缩略图高度一致，宽度各自按比例自适应，横向滚动正常且无溢出。
- A3: 剧照图片未加载时缩略图按默认 16:9 占位显示，加载完成后切换为实际比例。
- A4: 竖图与超宽图的缩略图被限制在合理比例范围（宽高比下限 1.0、上限 21/9），布局不溢出。
- A5: 预告片封面缩略图显示方式不变；点击剧照缩略图仍打开大图查看器并定位到对应图片。

# 约束与不变量

- 「预告片 / 剧照」区整体高度保持 164，横向列表滚动行为不变。
- 剧照缩略图保留现有 `Semantics`（button、label「查看剧照 N，共 M 张」）与 `movie-detail-screenshot-N` Key。
- 点击缩略图打开 `ImageGalleryViewer` 的行为与初始索引不变。
- 遵循项目规则：Material 3、无本地化（中文硬编码）、无触觉反馈改动。

# 决策

- D1（用户确认）：小图预览的缩放方式采用「宽度自适应」——缩略图高度统一，宽度按每张图片实际宽高比自适应，完整显示、不裁剪、不留空；横向列表各格子宽度不同；加载前按 16:9 占位。备选的「固定格子 contain 留空」与「仅处理极端比例」被否决。
- D2（Agent 决定，防溢出保护）：宽高比 clamp 范围取下限 1.0（正方形）、上限 21/9（约 2.33）；默认占位比例 16/9 处于范围内。仅影响极端比例图，属于防止布局溢出的保护性默认。
- D3（Agent 决定）：图片实际尺寸通过监听图片流（`ImageStream`/`ImageInfo`）获取，加载完成后更新对应缩略图宽度；获取尺寸的实现封装在缩略图组件内部，不改变 `CachedImage` 公共行为。

# 待解决问题

（当前无）

# 验证预期

- `flutter test` 通过；详情页剧照区测试需覆盖：缩略图宽度随图片宽高比变化、加载前后占位与切换、极端比例 clamp、点击与语义行为不变。
- `flutter analyze` 无新增告警。
