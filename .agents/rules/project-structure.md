# Project Structure

Prefer a structure that keeps feature-specific code close together while leaving room for shared layers when they add clarity.

## Top-Level Directory Layout

- **`lib/`**: Contains all Dart source code.
- **`test/`**: Unit, widget, and integration tests.
- **`assets/`**: Static assets like images and fonts.
- **`agents/`**: AI documentation and rules.
- **`scripts/`**: Optional utility scripts for build, release, or maintenance tasks.
- **`android/`, `ios/`, `web/`**: Platform-specific native code.

## `lib/` Architecture

### 1. Feature Modules (`lib/features/`)

Self-contained features that bundle their own data, logic, and UI. Use this for complex, isolated domains.

Some projects may use a hybrid organization with feature modules under `lib/features/` plus shared layers for models, providers, widgets, and localization files.

- Example: `lib/features/example_feature/`
  - `data/`: Data sources and repositories.
  - `presentation/`: Widgets and UI logic specific to the feature.

### 2. Core Layers (Shared)

Common components and application-wide logic.

- **`models/`**: Data classes and entity definitions (e.g., `user.dart`, `card.dart`).
- **`providers/`**: State management logic (Riverpod/Provider).
  - Group by domain when it improves discoverability.
- **`widgets/`**: UI components, organized by domain.
  - Contains both reusable atoms/molecules and screen-level widgets.
  - Shared widgets may be grouped by domain when that improves discoverability.
  - Keep shared helpers clearly separated from domain-specific widgets.
- **`l10n/`**: Localization files for the supported locales.

### 3. Utilities (`lib/utils/`)

Helper classes and extensions.

- **`extensions/`**: Dart extensions for core types (e.g., `context`, `string`, `date_time`).
- **`logger.dart`**: Application logging.
- **`error_handler.dart`**: Global error handling logic.

### 4. Entry Points

- **`main.dart`**: The primary application entry point.
