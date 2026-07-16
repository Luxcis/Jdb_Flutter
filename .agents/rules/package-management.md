# Package Management

- **Pub Tool:** Manage packages using the `pub` CLI tool if available (e.g., through an IDE or `flutter pub`).
- **External Packages:** If a new feature requires an external package, use the `pub_dev_search` tool (if available) to find it. Otherwise, identify a suitable, stable package on pub.dev manually.
- **Adding Dependencies:** To add a normal dependency, use the `pub` tool if available. Otherwise, run `flutter pub add <package_name>`.
- **Adding Dev Dependencies:** To add a dev dependency, use the `pub` tool with the `dev:` prefix if available. Otherwise, run `flutter pub add dev:<package_name>`.
- **Dependency Overrides:** To override a dependency version, use the `pub` tool with an override prefix if available. Otherwise, run `flutter pub add override:<package_name>:<version>`.
- **Removing Dependencies:** To remove a dependency, use the `pub` tool if available. Otherwise, run `dart pub remove <package_name>`.
