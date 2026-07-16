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

- **智能体主动**：当智能体认为当前修改适合发布为新版本时，应总结变更内容并向用户确认，获得授权后执行版本发布流程。
- **用户主动**：用户提出版本发布时，智能体应审查当前修改、总结变更要点，并向用户建议是否适合发布以及推荐的 bump 类型。
- **唯一修改点**：仅修改 `pubspec.yaml` 中的 `version:` 字段。
- **版本格式**：`X.Y.Z+N`（语义化版本），`N = X*10000 + Y*100 + Z`（MAJOR/MINOR/PATCH ≤ 99）。
- **Bump 类型**：未指定时默认 patch。
- **Tag**：`vX.Y.Z`，message 为 `Release vX.Y.Z`。
- **Commit**：`chore: bump version to X.Y.Z (versionCode N)`。
- **执行顺序**：修改 pubspec.yaml → `git add` → `git commit` → `git tag` → `git push --tags`。
- **安全检查**：提交前检查是否有除 pubspec.yaml 外的未提交变更；新 versionCode 必须 > 旧值且 ≤ 2100000000。

