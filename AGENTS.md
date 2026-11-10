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

In this repository, before starting work that may need code changes or investigation, pass the current user request to the read-only probe when a Comet workflow may already be active: `comet resume-probe . --stdin --json`.

- If the user explicitly invokes any Comet Skill through the host (for example, `@comet`, `/comet`, `@comet-native`, or `/comet-hotfix`), that explicit invocation takes precedence over this resume protocol; do not run the resume probe, and enter the invoked Skill directly.
- If the user explicitly invokes a non-Comet skill or slash command through the host, the task intent is already explicit in that invocation: do not run the resume probe, and execute the invoked skill directly.
- If you are already inside a Comet flow (including while waiting for the user to answer a question you asked in that flow), do not run the resume probe; treat replies such as option picks as continuation of the current change and proceed directly with the chosen option.
- Trust only the returned `workflow`, `skill`, and `entrySource`; project configuration or the no-config compatibility fallback alone selects them. Do not scan or switch to the other workflow.
- If the probe returns `auto_resume`, briefly state the selected active change and enter the permanent entry in `nextCommand`. Do not treat a state command as the resume entry or advance it blindly.
- If the probe returns `ask_user`, ask one short question and wait.
- If the current request did not explicitly invoke a Comet Skill and the probe returns `out_of_scope` or `none`, do not enter the Comet workflow.
- An `out_of_scope` or `none` result only means do not enter the Comet workflow for this new request; it never pauses or exits a Comet flow that is already in progress.
- If configuration or state is invalid and `nextCommand` is absent, stop and report the reason; do not guess another workflow.
- Never attach unrelated work merely because an active change exists. The Native entry inspects uncommitted work; the probe does not attribute it automatically.
</comet-ambient-resume>
