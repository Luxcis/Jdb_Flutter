### Task 1: 新增依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 编辑 pubspec.yaml dependencies**

```yaml
dependencies:
  flutter:
    sdk: flutter
  dynamic_color: ^1.8.1
  provider: ^6.1.5+1
  shared_preferences: ^2.5.5
  cupertino_icons: ^1.0.9
  crypto: ^3.0.6
  dio: ^5.7.0
  go_router: ^14.6.2
  json_annotation: ^4.9.0
  cached_network_image: ^3.4.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_launcher_icons: "^0.14.3"
  flutter_lints: ^6.0.0
  build_runner: ^2.4.13
  json_serializable: ^6.8.0
```

- [ ] **Step 2: 拉取依赖**

Run: `flutter pub get`
Expected: 退出码 0，无冲突。

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add dio/go_router/crypto/json_serializable deps for phase 0"
```

---

