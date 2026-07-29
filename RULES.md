# Project Specific Rules

## 项目概述

本项目为 JavDB 的第三方客户端，主要目标为实现其官方客户端除付费、在线观影、广告之外的所有功能。相关接口及使用方式文档在 `/docs/api` 下。

## 技术约定

### 主题（Theme）

- 遵循 **Material Design 3** 规范。
- 主题根据系统设置自动切换亮色/暗黑模式（`ThemeMode.system`）。
- 使用 `ColorScheme.fromSeed()` 生成色彩方案。

### 字体（Fonts）

- 使用系统字体，不额外引入自定义字体。
- 不配置 `google_fonts` 或自定义 `TextTheme.fontFamily`。

### 本地化（Localization / l10n）

- **不需要本地化**，项目所有文案直接使用中文硬编码。
- 不使用 `.arb` 文件，不依赖 `flutter_localizations`。

### 触觉反馈（Haptics）

- 不使用触觉反馈相关功能。

## 项目结构（Feature-First）

### 目录约定

```
lib/
├── core/                    # 公共层，被各 feature 依赖
│   ├── network/             # 网络请求、API 客户端
│   ├── router/              # 路由配置
│   ├── storage/             # 本地存储
│   └── widgets/             # 通用按钮、弹窗等可复用组件
├── features/                # 业务模块
│   └── <feature_name>/
│       ├── screens/         # 页面
│       ├── widgets/         # 模块内私有组件
│       ├── models/          # 数据模型
│       ├── services/        # 业务逻辑、API 调用
│       └── index.dart       # 对外入口，仅 export 路由需要的 Page 和公开模型
└── app.dart                 # 应用入口，注册路由、主题等
```

### 结构规则

1. **统一命名和层级**：每个 feature 下允许有 `screens/`、`widgets/`、`models/`、`services/`，新增时只在这几类目录中加，不随意在 feature 根目录创建新目录名。
2. **公共能力单独成层**：`lib/core/` 放网络、路由、存储、通用 UI 组件、常量等公共能力。feature 只依赖 core，feature 之间不互相依赖；core 不依赖具体 feature。
3. **约定入口文件**：每个 feature 必须有 `index.dart` 作为入口文件，对外只 export 需要被路由或其它模块引用的部分，内部实现细节不暴露。
4. **文档化**：在项目根目录维护 `STRUCTURE.md`，说明业务模块列表、公共层内容、新增 feature 需要创建的目录及命名约定。

## 版本控制

版本发布仅由**用户主动**触发，智能体不主动判断或建议版本发布。

### 发布流程

1. **拉取版本现状**：用户提出版本发布需求后，智能体需拉取远端所有 release 标签，并读取 `pubspec.yaml`
   中的 `version:` 字段，掌握当前版本状态。
2. **确定目标版本号**：
   - 若用户**未指定**目标版本号，智能体需展示当前所有已存在的版本号列表及版本演进说明，主动询问用户需要发布的目标版本号。
   - 若用户**已提供**目标版本号，智能体同样需展示当前所有已存在的版本号说明，再次和用户确认目标版本号，避免版本冲突。
3. **执行发布**：获取用户确认的正式版本号后，按顺序执行以下操作：
   1. 修改 `pubspec.yaml` 中的 `version:` 字段为确认的版本号，提交并推送到远端。
   2. 基于更新后的代码创建对应版本号的 Git 标签（格式：`vX.Y.Z`，message 为 `Release vX.Y.Z`），并推送到远端。
   3. 在代码托管平台创建对应版本的正式 Release，变更说明严格按以下格式生成：自动梳理两次版本之间的所有提交内容，分类整理为
      feat、fix 等类型的变更条目，并附上版本间的完整变更日志链接。示例格式：

   ```
   What's Changed
   fix: forward DeepSeek V4+ reasoning_effort for openai-compatible providers
   fix(models): add Anthropic native /v1/models fetcher(target V1 branch)
   feat(models): add Kimi K2.7 Code support
   Full Changelog: v1.9.11...v1.9.12
   ```

### 版本约定

- **唯一修改点**：仅修改 `pubspec.yaml` 中的 `version:` 字段。
- **版本格式**：`X.Y.Z+N`（语义化版本），`N = X*10000 + Y*100 + Z`（MAJOR/MINOR/PATCH ≤ 99）。
- **Tag 格式**：`vX.Y.Z`。
- **Commit 格式**：`chore: bump version to X.Y.Z (versionCode N)`。
- **安全检查**：提交前检查是否有除 `pubspec.yaml` 外的未提交变更；新 versionCode 必须 > 旧值且 ≤
  2100000000。

