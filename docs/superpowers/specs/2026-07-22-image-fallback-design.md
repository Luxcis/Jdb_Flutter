# 图片加载失败占位图设计

## 目标

在网络影片图片或演员头像加载失败时显示项目内置占位图，替代当前破图图标，并按展示场景选择正确宽高比的资源。

## 资源与映射

- 缩略图场景使用 `assets/images/noimage_147x200.jpg`。
- 宽封面场景使用 `assets/images/noimage_600x404.jpg`。
- 男演员头像使用 `assets/images/actor_unknow_male_200x200.jpg`。
- 女性或未知性别演员头像使用 `assets/images/actor_unknow_200x200.jpg`。
- `pubspec.yaml` 声明整个 `assets/images/` 目录，确保现有和新增图片统一打包。

占位图类型按组件展示场景决定，不按最终请求 URL 字段决定。影片卡片即使在 `thumbUrl` 缺失后改用 `coverUrl`，加载失败仍显示竖向缩略图占位图。

## 组件设计

### CachedImage

为现有 `CachedImage` 增加可选 `fallbackAsset` 参数。网络图片成功、加载中、解密缓存和尺寸适配逻辑保持不变；仅在 `CachedNetworkImage.errorWidget` 被调用且指定了资源时渲染 `Image.asset`。未指定资源时继续显示现有破图图标。

### MovieCoverImage

新增公共影片图片组件，接收图片 URL、`MovieImageVariant.thumbnail` 或 `MovieImageVariant.cover`、尺寸和 `BoxFit`。组件将场景映射为对应影片占位图并委托 `CachedImage` 加载。

- `MovieCard`、`MovieListTile` 使用 `thumbnail`。
- 首页“佳片推荐”和影片详情顶部封面使用 `cover`。
- 剧照继续直接使用 `CachedImage`，失败时不使用影片封面占位图。

### ActorAvatarImage

新增公共演员头像组件，接收 `ActorSummary`、尺寸和 `BoxFit`。当 `actor.gender` 忽略大小写后等于 `male` 时选择男性占位图，其他值或空值选择女性通用占位图。

`ActorCard`、演员首页分组、演员列表和演员详情统一使用该组件。

## 数据模型

`ActorSummary` 增加可空 `gender` 字段，`ActorDetail` 继承该字段。`normalizeActorSummaryJson` 将 API 的 `gender` 转为字符串；缺失时保留 `null`。更新 JSON 生成文件，使序列化和反序列化均包含该字段。

## 错误处理与无障碍

- 本地资源仅在网络图片最终失败后出现，加载中仍展示进度指示器。
- 占位图沿用调用者的裁剪、尺寸和 `BoxFit`，避免布局跳变或溢出。
- 图片组件提供可选语义标签；影片和演员调用点使用影片标题或演员名称，保证占位图出现时仍可被辅助功能识别。

## 测试与验收

- `CachedImage` 测试验证指定和未指定 `fallbackAsset` 时的错误组件。
- `MovieCoverImage` 测试验证缩略图与宽封面资源映射，以及卡片场景在 URL 回退时仍使用缩略图占位。
- `ActorAvatarImage` 测试验证男性、女性、未知和大小写性别映射。
- 数据标准化测试验证 `gender` 解析与缺失兼容。
- 运行完整 `flutter test` 与 `dart analyze`。
- 安装到 Android 模拟器，用 `adb_tool` 检查详情宽封面和演员头像的占位图比例、裁剪及页面布局。
