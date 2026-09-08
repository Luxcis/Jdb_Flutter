# AI rules for Flutter

You are an expert in Flutter and Dart development. Your goal is to build beautiful, performant, and maintainable applications following modern best practices. You have expert experience with writing, testing, and running Flutter applications for various platforms (desktop, web, and mobile).

Detailed coding standards and best practices are organized by topic in the `@agents/rules` directory. Please refer to those files for the full set of rules (covering style guides, state management, testing, architecture, and more).

Keep the topic rules generic and reusable as they are shared accross Flutter projects. Put project-specific conventions in `@RULES.md`.

## Rule Loading Triggers

### 📝 interaction-guidelines.md - Core Engineering Principles

**Load when:**

- Always (implicitly)
- Interacting with the user
- determining how to format responses or usage of tools

**Keywords:** interaction, persona, explanation, tools, dart\_format, dart\_fix

**Location**: .agents/rule/interaction-guidelines.md

### 🏗️ project-structure.md - Project Structure

**Load when:**

- Understanding file organization
- creating new files or folders
- Navigating the codebase

**Keywords:** structure, architecture, folders, features, core, layers, modules

**Location**: .agents/rule/project-structure.md

### 🌟 best-practices.md - Best Practices

**Load when:**

- Writing any Dart or Flutter code
- optimizing performance
- reviewing code
- choosing state management solutions

**Keywords:** best practices, effective dart, immutability, riverpod, solid, performance, optimization

**Location**: .agents/rule/best-practices.md

### 🎨 ui-ux.md - UI/UX & Theming

**Load when:**

- Creating or modifying UI
- working with themes (Material 3)
- implementing responsive layouts
- handling assets and images

**Keywords:** ui, ux, design, theme, material 3, layout, assets, images, colors, typography

**Location**: .agents/rule/ui-ux.md

### 🌍 localizations.md - Localizations

**Load when:**

- Adding user-facing text
- working with `.arb` files
- using the localization extension

**Keywords:** localization, l10n, translation, arb, internationalization, strings, text

**Location**: .agents/rule/localizations.md

### 🧩 RULES.md - Project-Specific Conventions

**Load when:**

- Everytime!

**Keywords:** project-specific, repo conventions, structure, entry point, l10n, theme, fonts, haptics

**Location**: ./RULES.md

### 💾 data-handling-serialization.md - Data Handling & Serialization

**Load when:**

- Working with JSON
- creating data models
- implementing serialization

**Keywords:** json, serialization, json\_serializable, models, data, parsing

**Location**: .agents/rule/data-handling-serialization.md

### 🧪 testing.md - Testing

**Load when:**

- Writing or running tests
- setting up test environments
- understanding testing strategies (unit, widget, integration)

**Keywords:** testing, unit test, widget test, integration test, flutter\_test, mockito

**Location**: .agents/rule/testing.md

### 📦 package-management.md - Package Management

**Load when:**

- Adding or removing dependencies
- managing pubspec.yaml
- resolving version conflicts

**Keywords:** package, dependency, pub, pubspec, version, library

**Location**: .agents/rule/package-management.md

### 📝 documentation.md - Documentation

**Load when:**

- Writing comments or API documentation
- explaining complex logic
- formatting documentation

**Keywords:** documentation, comments, dartdoc, api, explanation

**Location**: .agents/rule/documentation.md

### ♿ accessibility.md - Accessibility (A11Y)

**Load when:**

- checking for accessibility compliance
- implementing screen reader support
- adjusting color contrast and font scaling

**Keywords:** accessibility, a11y, semantics, screen reader, contrast, scaling

**Location**: .agents/rule/accessibility.md

### When working on a new feature

Load: `interaction-guidelines.md`, `project-structure.md`, `best-practices.md`, `ui-ux.md`, `localizations.md`

### When creating data models

Load: `data-handling-serialization.md`, `best-practices.md`

### When writing tests

Load: `testing.md`, `best-practices.md`

### When creating a new screen/widget

Load: `ui-ux.md`, `localizations.md`, `accessibility.md`, `best-practices.md`

### When reviewing code

Load: `best-practices.md`, `documentation.md`, `interaction-guidelines.md`

### When fixing bugs

Load: `best-practices.md`, `testing.md`, `interaction-guidelines.md`

## Loading Strategy

1. **Always load** **`project-specificities.md`,** **`interaction-guidelines.md`** **and** **`best-practices.md`** - foundation principles
2. **Load domain-specific rules** based on the task (e.g. `ui-ux.md` for UI work)
3. **Load supporting rules** as needed (e.g., `testing.md` when implementing tests)
4. **Keep loaded rules minimal** - Only what's directly relevant
5. **Refresh rules** when switching contexts or tasks

<comet-ambient-resume>
<!-- Managed by Comet. Edits inside this block may be replaced by comet init/update. -->
<!-- Contract: comet.resume_probe.v2 -->

## Comet Ambient Resume

在这个仓库中，开始处理需要改动或调查的任务前，如果可能存在活跃 Comet workflow，把当前用户请求传入只读探针：
`comet resume-probe . --stdin --json`。

- 如果用户通过宿主明确调用任意 Comet Skill（例如 `@comet`、`/comet`、`@comet-native` 或 `/comet-hotfix`
  ），显式调用优先于本恢复协议；不要运行 resume probe，直接进入被调用的 Skill。
- 如果用户通过宿主明确调用的是非 Comet 的 Skill 或斜杠命令，任务意图已由该调用明确：不要运行 resume
  probe，直接执行该 Skill。
- 如果你正在 Comet 流程内（包括正在等待用户回复你在流程中提出的问题），不要运行 resume
  probe；把这类回复（例如方案/选项选择）当作当前 change 的继续，直接按用户的选择推进。
- 只信任返回的 `workflow`、`skill` 和 `entrySource`；它们只由项目配置或无配置兼容回退决定。不得扫描或切换另一套
  workflow。
- 如果 probe 返回 `auto_resume`，简短说明选中的 active change，并进入 `nextCommand`
  指向的永久入口。不要把状态命令当作恢复入口直接推进。
- 如果 probe 返回 `ask_user`，只问一个简短问题并等待用户回复。
- 如果当前请求未明确调用 Comet Skill，且 probe 返回 `out_of_scope` 或 `none`，不要进入 Comet workflow。
- `out_of_scope` 或 `none` 只表示不要因为这个新请求进入 Comet workflow；它绝不表示要暂停或退出一个已在进行的
  Comet 流程。
- 如果配置或状态无效且没有 `nextCommand`，停止并报告原因；不要猜测另一个 workflow。
- 不能只因为存在 active change 就把无关任务挂到该 change。Native 的未提交改动由 Native 入口检查，不由探针自动归因。
  </comet-ambient-resume>
