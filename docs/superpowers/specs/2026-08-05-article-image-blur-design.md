# 资讯详情图片自动模糊设计

## 目标

让资讯详情页正文中的图片自动跟随全局"模糊图片"开关（`blurMovieImages`），复用 `CachedImage` 现有的解密缓存与模糊能力，不重复实现模糊逻辑。

## 已确认需求

- 资讯详情正文图片跟随全局 `blurMovieImages` 开关（默认开启）。
- 模糊范围仅限正文中的网络图片（`http`/`https`）；base64、asset 等非网络图片保持 flutter_html 内置行为。
- 不做图片点击放大，不新增模糊强度调节。
- 开关关闭后，已显示的资讯正文图片立即恢复清晰。
- 不引入新依赖。

## 架构设计

### 图片渲染

flutter_html 3.0.0 通过 `Html.extensions` 扩展渲染，用户传入的扩展优先级高于内置 `ImageBuiltIn`。新增 `CachedImageHtmlExtension extends HtmlExtension`：

- `supportedTags` 为 `{"img"}`。
- `prepare` 阶段不接管：由内置 `ImageBuiltIn` 生成 `ImageElement`，保留原有 CSS 尺寸解析。
- `build` 阶段接管 `img`：仅当 `styledElement` 是 `ImageElement`、`src` 为 `http(s)` 且非 `.svg` 时匹配。
- `build` 返回 `WidgetSpan`，内部用 `CssBoxWidget(style, childIsReplaced: true)` 包裹 `CachedImage`，保持与内置渲染一致的 CSS 宽高行为。
- `CachedImage` 已内部通过 `context.watch<SettingsProvider?>()?.blurMovieImages ?? true` 自动决定是否模糊，无需传参。

### 数据流

正文 HTML → `resolveArticleImageUrls`（相对路径拼接完整 URL）→ `Html(data, extensions: [CachedImageHtmlExtension()])` → 图片经 `CachedImage` 渲染 → 模糊状态由 `SettingsProvider.blurMovieImages` 驱动，设置变更时组件树自动重建。

### 文件组织

- 新增 `lib/features/articles/widgets/cached_image_html_extension.dart`，导出 `CachedImageHtmlExtension`。
- `article_detail_screen.dart` 的 `Html` 组件增加 `extensions` 参数。

## 异常与边界处理

- 非网络图片（base64、`asset:`、svg）不匹配扩展，回退 flutter_html 内置渲染。
- 缺少 `src` 属性的 `img` 不匹配扩展。
- 图片加载失败由 `CachedImage` 内置 `errorWidget` 兜底（broken_image 图标或占位图），占位内容保持清晰。
- 本功能不修改 URL 拼接、图片缓存、解密规则或正文样式。

## 测试与验收

### 自动化测试

- `CachedImageHtmlExtension` 单元测试：网络图片匹配并返回含 `CachedImage` 的 `WidgetSpan`；base64/asset 图片不匹配。
- 资讯详情 widget 测试：渲染含 `<img>` 的正文时出现 `CachedImage`；全局开关关闭时无模糊构建器，开启时有。
- 运行相关测试、`flutter test` 和 `dart analyze`。

### 设备验收

1. 资讯详情正文图片在开关开启时模糊。
2. 设置页关闭开关后，正文图片恢复清晰，切换回详情页同样清晰。
3. 重新开启后恢复模糊。

## 成功标准

- 资讯详情正文图片统一遵守全局模糊开关。
- 非网络图片与失败占位不被误模糊。
- 不引入新依赖，不改变现有正文样式与图片地址规则。
- 自动化测试、静态分析全部通过。
