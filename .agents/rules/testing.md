# Testing

## Running Tests

- **Run Tests:** Use the `run_tests` tool (if available in the environment) to execute tests. Otherwise, run tests manually with `flutter test`.
- **Unit Tests:** Use the **package:test** framework for writing unit tests (pure Dart logic tests).
- **Widget Tests:** Use **package:flutter_test** to write widget tests for UI components and interactions.
- **Integration Tests:** Use **package:integration_test** to write integration tests that run on a device or emulator and verify end-to-end app behavior.
- **Assertions:** Prefer using the **package:checks** library for assertions in tests, as it provides more expressive matchers than the default `expect` matchers.

## Best Practices

- **Test Structure:** Organize tests using the Arrange-Act-Assert pattern (also known as Given-When-Then) for clarity.
- **Unit Test Coverage:** Write unit tests for business logic in the domain layer, for data layer code (like repositories or services), and for state management classes.
- **Widget Test Coverage:** Write widget tests to verify widget behavior (UI rendering, user interactions) in isolation.
- **Integration Test Usage:** Use integration tests for full user scenarios and flows to catch issues that unit/widget tests might miss.
- **Integration Test Setup:** Include the `integration_test` package (from the Flutter SDK) as a dev dependency (`sdk: flutter`) in pubspec.yaml for integration testing.
- **Prefer Fakes to Mocks:** Use fake implementations or stubs instead of heavy mocking when possible. If you do need to create mocks, consider using `mockito` or `mocktail`. (Avoid code generation for mocks if possible; prefer simpler solutions.)
- **Aim for Coverage:** Strive for high test coverage, but focus on meaningful tests that validate critical functionality rather than chasing an arbitrary percentage.
