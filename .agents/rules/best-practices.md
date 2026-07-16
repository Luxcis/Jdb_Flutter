# Best Practices

## Dart Best Practices

- **Effective Dart:** Follow the official [Effective Dart guidelines](https://dart.dev/effective-dart) for style and conventions.
- **Class Organization:** Define closely related classes in the same library file. For large modules, use one top-level library file that exports smaller private libraries.
- **Library Organization:** Group related library files into the same folder (feature or module).
- **Trailing Commas:** Avoid using trailing inline comments in code.
- **Async/Await:** Use `async`/`await` for asynchronous operations with proper error handling.
  - Use `Future` and `await` for single asynchronous results.
  - Use `Stream` (with `StreamBuilder`) for sequences of asynchronous events.
- **Null Safety:** Write null-safe code. Leverage Dart’s null safety features and avoid using the `!` operator unless you are certain the value is non-null.
- **Pattern Matching:** Use Dart’s pattern matching features (e.g., in `switch` statements or `if` case expressions) when they simplify the code.
- **Records:** Use record types to return multiple values from a function when defining a full class would be overkill.
- **Switch Statements:** Prefer exhaustive `switch` statements or `switch` expressions (no need for a `break` in Dart) to handle all cases explicitly.
- **Exception Handling:** Use `try/catch` blocks to handle exceptions. Throw exceptions that accurately describe the error context, and use custom exception types for domain-specific errors.
- **Arrow Functions:** Use arrow syntax (`=>`) for simple one-line methods or functions.

## Flutter Best Practices

- **Immutability:** Widgets (especially subclasses of `StatelessWidget`) should be immutable. Flutter will rebuild the widget tree when the UI needs to update, so never mutate widget instances.
- **Composition:** Build UIs by composing small widgets rather than extending big ones. This avoids deeply nested builds and keeps widgets focused.
- **Private Widgets:** Factor out pieces of UI into small, private widget classes (instead of helper methods that return widgets) to make code more readable and reusable.
- **Build Method Decomposition:** Break down large `build()` methods into multiple smaller widgets or helper methods to improve readability.
- **ListView Performance:** Use `ListView.builder` (or `SliverList`/`ListView.separated`) for long or infinite lists, so that widgets are created lazily as they scroll into view.
- **Expensive Computation:** Use isolates (via `compute()`) to offload expensive work (e.g., heavy calculations or JSON parsing) so the main UI thread isn’t blocked.
- **Const Constructors:** Use `const` constructors for widgets and other objects wherever possible. This allows Flutter to optimize and avoid unnecessary rebuilds.
- **No Heavy Work in build():** Avoid performing expensive operations (like network requests or large calculations) directly inside a widget’s `build()` method.
- **SOLID Principles:** Apply SOLID principles throughout the codebase.
- **Concise and Declarative:** Write concise, modern Dart code. Prefer functional and declarative programming patterns.
- **Composition over Inheritance:** Favor composition for building complex widgets and logic, rather than deep class inheritance.
- **State Management:** Separate ephemeral (UI-local) state from app state. Use a state management solution like [Riverpod](https://pub.dev/packages/flutter_riverpod) for app state to enforce separation of concerns.
- **Widgets for UI:** In Flutter, everything in the UI is a widget. Compose complex UIs from smaller, reusable widgets.
- **Navigation:** Use a modern routing package like `auto_route` or `go_router` for navigation.

## API Design Principles

When designing reusable APIs (e.g., for a library or shared component), keep the following principles in mind:

- **Consider the User:** Design APIs from the perspective of the developer who will use them. The API should be intuitive, easy to understand, and hard to misuse.
- **Documentation is Essential:** Comprehensive documentation is part of good API design. Ensure the API is well-documented with clear usage examples.
