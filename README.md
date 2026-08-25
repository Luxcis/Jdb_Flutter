# Jade

**Jade** 是 JavDB 的第三方 Flutter 客户端，目标是实现官方客户端除付费、在线观影、广告之外的全部功能。项目包名为 `jade`，当前版本 `0.11.2`。

## 特性

- **5 个主导航 Tab**：首页、排行榜、类别、演员、我的
- **影片浏览与管理**：详情页（磁链、短评、相关清单）、想看/看过、收藏、关注、清单、近期浏览
- **榜单与分类**：Top250、看热播、有码、无码、欧美、FC2、动漫
- **搜索**：影片、演员、系列、片商、导演、清单、番号，以及磁链搜索
- **演员/导演/片商/系列**：列表、详情、收藏
- **文章与短评**：AV 资讯（HTML 渲染）、热门短评
- **动态域名**：启动解密备用域名，支持线路自动轮转与手动选择
- **预览播放**：影片预告片/剧照预览
- **Material 3 主题**：跟随系统亮/暗模式，支持动态取色
- **GitHub 代理**：检查更新与下载 APK 时可通过自定义代理加速

## 技术栈

- **框架**：Flutter / Dart
- **UI**：Material 3
- **状态管理**：`provider`（`ChangeNotifier` / `ValueNotifier`）
- **路由**：`go_router`（`StatefulShellRoute` 保活 5 Tab）
- **网络**：`dio`
- **序列化**：`json_annotation` + `json_serializable`（`build_runner` 生成）
- **存储**：`shared_preferences`、`flutter_secure_storage`
- **播放**：`media_kit` / `media_kit_video`

## 本地开发

### 环境要求

- Flutter SDK 3.44+
- Dart 3.8+
- JDK 18+（Android 构建）
- Android SDK（目标平台）

### 安装依赖

```bash
flutter pub get
```

### 运行

```bash
flutter run
```

### 静态分析

```bash
flutter analyze
```

### 测试

```bash
flutter test
```

项目包含约 850 个单元/组件/集成测试用例。

### 代码生成

修改数据模型后执行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 项目结构

遵循 **Feature-First** 分层，公共能力放在 `lib/core/`，业务模块按 `lib/features/<feature_name>/` 组织。详情见 [STRUCTURE.md](./STRUCTURE.md)。

```
lib/
├── main.dart        # 应用启动
├── app.dart         # MyApp
├── core/            # 公共层：网络、路由、存储、组件、主题
└── features/        # 业务模块（17 个）
```

## 文档

- [项目结构说明](STRUCTURE.md)
- [产品需求规范](docs/main/jdb-product-spec.md)
- [API 接口文档](docs/main/api/api-reference.md)
- [API 逆向工程文档](docs/main/README.md)

## 发布流程

版本发布仅由用户主动触发。智能体不主动判断或建议版本发布。发布时将 `pubspec.yaml` 的 `version:` 提升到目标版本号，创建对应 `vX.Y.Z` 标签，并在代码托管平台生成 Release，触发 GitHub Actions 自动打包 APK。

## 许可证

本项目使用 [GPL-3.0](./LICENSE.txt) 许可证。
