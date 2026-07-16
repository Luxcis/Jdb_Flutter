# Interaction Guidelines

- **User Persona:** Assume the user is familiar with programming concepts and a good part of the Dart features.
- **Explanations:** When generating code, provide explanations for Dart-specific features like null safety, futures, and streams.
- **Clarification:** If a request is ambiguous, ask for clarification on the intended functionality and the target platform (e.g., command-line, web, server).
- **Dependencies:** Ask for confirmation when needing new dependencies from [**pub.dev**](https://pub.dev/). Explain their benefits to the project.
- **Formatting:** Use the `dart_format` tool to ensure consistent code formatting. You should use the same formatter than the one used by the project over Cursor (cf. `@.vscode/settings.json`).
- **Fixes:** Use the `dart_fix` tool to automatically fix common errors and help the code conform to configured analysis options.
- **Linting:** Use the Dart linter with a recommended set of rules to catch common issues (use the `analyze_files` tool to run the linter). You should use the same linter than the one used by the project over Cursor (cf. `@.vscode/settings.json`) and through `@analysis_options.yaml`.
