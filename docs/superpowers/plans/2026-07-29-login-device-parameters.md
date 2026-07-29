# Login Device Parameters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Android login request derive and cache device identity exactly as the official 1.9.35 client contract requires.

**Architecture:** Add a core `LoginDeviceInfoService` behind a small `LoginDeviceParametersProvider` interface. The service reads an injectable Android snapshot source, UUID generator, and UUID store; `LoginPage` consumes only the provider and sends its values as `FormData`.

**Tech Stack:** Flutter, Dart 3.8+, `device_info_plus ^11.5.0`, `uuid ^4.6.0`, `shared_preferences`, `flutter_test`

## Global Constraints

- Scope is login only; do not change registration, startup, activation, or other request parameters.
- `username` is the input text after `trim()`.
- `password` is the unmodified input text.
- Do not encode, hash, or encrypt `username` or `password`.
- Cache key is exactly `key_device_uuid` through `StorageKeys.deviceUuid`.
- The exceptional Android ID is exactly `9774d56d682e549c` and must use UUID v4.
- All other Android IDs use UUID v5 with namespace `6ba7b812-9dad-11d1-80b4-00c04fd430c8` and name equal to `androidInfo.id`.
- `device_name = androidInfo.manufacturer`.
- `device_model = "${androidInfo.model}/${androidInfo.board}"`.
- `system_version = androidInfo.version.release`.
- Fixed values are `platform=android`, `app_channel=official`, `app_version=official`, and `app_version_number=1.9.35`.
- A device-read, UUID-generation, or UUID-persistence failure must abort the request and use the login page's existing error display.
- Keep the request encoding as Dio `FormData`.
- Use `device_info_plus ^11.5.0`: the current project uses AGP 8.11.1, while `device_info_plus 12.3+` requires AGP 8.12.1.

---

## File Map

- Create `lib/core/device/login_device_info_service.dart`: device snapshot model, provider/source/store/generator interfaces, production adapters, UUID cache algorithm, and request-field model.
- Create `test/core/device/login_device_info_service_test.dart`: unit coverage for cache reuse, UUID v4/v5 selection, field mapping, and persistence failure.
- Modify `lib/features/auth/screens/login_screen.dart`: remove timestamp UUID and hardcoded legacy device fields; consume `LoginDeviceParametersProvider`.
- Modify `test/features/auth/login_screen_test.dart`: inject a fake provider and assert the complete multipart contract, username trim, and password preservation.
- Modify `pubspec.yaml`: add direct dependencies.
- Modify `pubspec.lock`: record resolved dependency graph.

### Task 1: Core login device information service

**Files:**

- Create: `lib/core/device/login_device_info_service.dart`
- Create: `test/core/device/login_device_info_service_test.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`

**Interfaces:**

- Produces: `AndroidDeviceSnapshot`
- Produces: `LoginDeviceParameters`
- Produces: `LoginDeviceParametersProvider.load(): Future<LoginDeviceParameters>`
- Produces: `LoginDeviceInfoService.createDefault(): Future<LoginDeviceInfoService>`
- Produces: `LoginDeviceInfoService.load(): Future<LoginDeviceParameters>`
- Produces: `AndroidDeviceSnapshotSource.read(): Future<AndroidDeviceSnapshot>`
- Produces: `DeviceUuidStore.read(): String?`
- Produces: `DeviceUuidStore.write(String value): Future<void>`
- Produces: `DeviceUuidGenerator.v4(): String`
- Produces: `DeviceUuidGenerator.v5(String namespace, String name): String`

- [ ] **Step 1: Add compatible direct dependencies**

Run:

```bash
flutter pub add device_info_plus:^11.5.0 uuid:^4.6.0
```

Expected:

- `pubspec.yaml` contains both packages under `dependencies`.
- `pubspec.lock` marks `device_info_plus` and `uuid` as direct main dependencies.
- Dependency resolution succeeds without changing Android Gradle Plugin versions.

- [ ] **Step 2: Write failing service tests**

Create `test/core/device/login_device_info_service_test.dart` with focused fakes and these tests:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/device/login_device_info_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  const snapshot = AndroidDeviceSnapshot(
    id: 'android-id-123',
    manufacturer: 'Google',
    model: 'Pixel 9',
    board: 'tokay',
    systemVersion: '15',
  );

  test('缓存 UUID 存在时复用缓存并映射官方登录设备字段', () async {
    final store = _FakeStore(value: 'cached-device-uuid');
    final generator = _FakeGenerator();
    final service = LoginDeviceInfoService(
      source: _FakeSource(snapshot),
      store: store,
      generator: generator,
    );

    final result = await service.load();

    expect(result.toMap(), {
      'device_uuid': 'cached-device-uuid',
      'device_name': 'Google',
      'device_model': 'Pixel 9/tokay',
      'platform': 'android',
      'system_version': '15',
      'app_channel': 'official',
      'app_version': 'official',
      'app_version_number': '1.9.35',
    });
    expect(generator.v4Calls, 0);
    expect(generator.v5Calls, 0);
    expect(store.writes, isEmpty);
  });

  test('异常 Android ID 使用 UUID v4 并持久化', () async {
    final store = _FakeStore();
    final generator = _FakeGenerator(v4Result: 'generated-v4');
    final service = LoginDeviceInfoService(
      source: _FakeSource(
        const AndroidDeviceSnapshot(
          id: '9774d56d682e549c',
          manufacturer: 'Google',
          model: 'sdk_gphone64_arm64',
          board: 'goldfish',
          systemVersion: '14',
        ),
      ),
      store: store,
      generator: generator,
    );

    final result = await service.load();

    expect(result.deviceUuid, 'generated-v4');
    expect(generator.v4Calls, 1);
    expect(generator.v5Calls, 0);
    expect(store.writes, ['generated-v4']);
  });

  test('正常 Android ID 使用指定 namespace 和 Android ID 生成 UUID v5', () async {
    final store = _FakeStore();
    final generator = _FakeGenerator(v5Result: 'generated-v5');
    final service = LoginDeviceInfoService(
      source: _FakeSource(snapshot),
      store: store,
      generator: generator,
    );

    final result = await service.load();

    expect(result.deviceUuid, 'generated-v5');
    expect(generator.v4Calls, 0);
    expect(generator.v5Calls, 1);
    expect(
      generator.lastNamespace,
      '6ba7b812-9dad-11d1-80b4-00c04fd430c8',
    );
    expect(generator.lastName, 'android-id-123');
    expect(store.writes, ['generated-v5']);
  });

  test('uuid 包适配器按指定 namespace 生成稳定 UUID v5', () {
    final result = const PackageDeviceUuidGenerator().v5(
      '6ba7b812-9dad-11d1-80b4-00c04fd430c8',
      'android-id-123',
    );

    expect(result, '612a9cc0-66ad-51b0-ae5c-5bdafc91d3d7');
    expect(Uuid.isValidUUID(fromString: result), isTrue);
  });

  test('UUID 持久化失败时抛出异常而不是返回未缓存参数', () async {
    final service = LoginDeviceInfoService(
      source: _FakeSource(snapshot),
      store: _FakeStore(writeError: StateError('write failed')),
      generator: _FakeGenerator(v5Result: 'generated-v5'),
    );

    await expectLater(service.load(), throwsA(isA<StateError>()));
  });
}

final class _FakeSource implements AndroidDeviceSnapshotSource {
  _FakeSource(this.snapshot);

  final AndroidDeviceSnapshot snapshot;

  @override
  Future<AndroidDeviceSnapshot> read() async => snapshot;
}

final class _FakeStore implements DeviceUuidStore {
  _FakeStore({this.value, this.writeError});

  String? value;
  final Object? writeError;
  final List<String> writes = [];

  @override
  String? read() => value;

  @override
  Future<void> write(String value) async {
    if (writeError case final error?) throw error;
    this.value = value;
    writes.add(value);
  }
}

final class _FakeGenerator implements DeviceUuidGenerator {
  _FakeGenerator({
    this.v4Result = 'fake-v4',
    this.v5Result = 'fake-v5',
  });

  final String v4Result;
  final String v5Result;
  var v4Calls = 0;
  var v5Calls = 0;
  String? lastNamespace;
  String? lastName;

  @override
  String v4() {
    v4Calls++;
    return v4Result;
  }

  @override
  String v5(String namespace, String name) {
    v5Calls++;
    lastNamespace = namespace;
    lastName = name;
    return v5Result;
  }
}
```

- [ ] **Step 3: Run the service test to verify RED**

Run:

```bash
flutter test test/core/device/login_device_info_service_test.dart
```

Expected: FAIL because `login_device_info_service.dart` and its declared types do not exist.

- [ ] **Step 4: Implement the minimal core service**

Create `lib/core/device/login_device_info_service.dart`:

```dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _invalidAndroidId = '9774d56d682e549c';
const _deviceUuidNamespace = '6ba7b812-9dad-11d1-80b4-00c04fd430c8';

final class AndroidDeviceSnapshot {
  const AndroidDeviceSnapshot({
    required this.id,
    required this.manufacturer,
    required this.model,
    required this.board,
    required this.systemVersion,
  });

  final String id;
  final String manufacturer;
  final String model;
  final String board;
  final String systemVersion;
}

final class LoginDeviceParameters {
  const LoginDeviceParameters({
    required this.deviceUuid,
    required this.deviceName,
    required this.deviceModel,
    required this.systemVersion,
  });

  final String deviceUuid;
  final String deviceName;
  final String deviceModel;
  final String systemVersion;

  Map<String, String> toMap() => {
    'device_uuid': deviceUuid,
    'device_name': deviceName,
    'device_model': deviceModel,
    'platform': 'android',
    'system_version': systemVersion,
    'app_channel': 'official',
    'app_version': 'official',
    'app_version_number': '1.9.35',
  };
}

abstract interface class LoginDeviceParametersProvider {
  Future<LoginDeviceParameters> load();
}

abstract interface class AndroidDeviceSnapshotSource {
  Future<AndroidDeviceSnapshot> read();
}

abstract interface class DeviceUuidStore {
  String? read();
  Future<void> write(String value);
}

abstract interface class DeviceUuidGenerator {
  String v4();
  String v5(String namespace, String name);
}

final class DeviceInfoPlusAndroidSource
    implements AndroidDeviceSnapshotSource {
  DeviceInfoPlusAndroidSource({DeviceInfoPlugin? plugin})
    : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  @override
  Future<AndroidDeviceSnapshot> read() async {
    final info = await _plugin.androidInfo;
    return AndroidDeviceSnapshot(
      id: info.id,
      manufacturer: info.manufacturer,
      model: info.model,
      board: info.board,
      systemVersion: info.version.release,
    );
  }
}

final class SharedPreferencesDeviceUuidStore implements DeviceUuidStore {
  const SharedPreferencesDeviceUuidStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? read() => _preferences.getString(StorageKeys.deviceUuid);

  @override
  Future<void> write(String value) async {
    final persisted = await _preferences.setString(
      StorageKeys.deviceUuid,
      value,
    );
    if (!persisted) {
      throw StateError('设备 UUID 持久化失败');
    }
  }
}

final class PackageDeviceUuidGenerator implements DeviceUuidGenerator {
  const PackageDeviceUuidGenerator();

  static const _uuid = Uuid();

  @override
  String v4() => _uuid.v4();

  @override
  String v5(String namespace, String name) => _uuid.v5(namespace, name);
}

final class LoginDeviceInfoService
    implements LoginDeviceParametersProvider {
  const LoginDeviceInfoService({
    required AndroidDeviceSnapshotSource source,
    required DeviceUuidStore store,
    required DeviceUuidGenerator generator,
  }) : _source = source,
       _store = store,
       _generator = generator;

  final AndroidDeviceSnapshotSource _source;
  final DeviceUuidStore _store;
  final DeviceUuidGenerator _generator;

  static Future<LoginDeviceInfoService> createDefault() async {
    final preferences = await SharedPreferences.getInstance();
    return LoginDeviceInfoService(
      source: DeviceInfoPlusAndroidSource(),
      store: SharedPreferencesDeviceUuidStore(preferences),
      generator: const PackageDeviceUuidGenerator(),
    );
  }

  @override
  Future<LoginDeviceParameters> load() async {
    final device = await _source.read();
    var deviceUuid = _store.read();

    if (deviceUuid == null || deviceUuid.isEmpty) {
      deviceUuid = device.id == _invalidAndroidId
          ? _generator.v4()
          : _generator.v5(_deviceUuidNamespace, device.id);
      await _store.write(deviceUuid);
    }

    return LoginDeviceParameters(
      deviceUuid: deviceUuid,
      deviceName: device.manufacturer,
      deviceModel: '${device.model}/${device.board}',
      systemVersion: device.systemVersion,
    );
  }
}
```

- [ ] **Step 5: Format and verify GREEN**

Run:

```bash
dart format lib/core/device/login_device_info_service.dart test/core/device/login_device_info_service_test.dart
flutter test test/core/device/login_device_info_service_test.dart
```

Expected: formatting completes and all five service tests PASS.

- [ ] **Step 6: Commit the service slice**

```bash
git add pubspec.yaml pubspec.lock lib/core/device/login_device_info_service.dart test/core/device/login_device_info_service_test.dart
git commit -m "feat(auth): add official login device parameters"
```

### Task 2: Wire official device parameters into LoginPage

**Files:**

- Modify: `lib/features/auth/screens/login_screen.dart`
- Modify: `test/features/auth/login_screen_test.dart`

**Interfaces:**

- Consumes: `LoginDeviceParametersProvider.load(): Future<LoginDeviceParameters>`
- Consumes: `LoginDeviceParameters.toMap(): Map<String, String>`
- Preserves: `LoginPage({Key? key, LoginDeviceParametersProvider? deviceParametersProvider})`

- [ ] **Step 1: Replace the widget test expectation with the official contract**

In `test/features/auth/login_screen_test.dart`:

1. Remove `StorageKeys` and `shared_preferences` setup used only for the old timestamp/cached implementation.
2. Import `package:jade/core/device/login_device_info_service.dart`.
3. Add this fake:

```dart
final class _FakeLoginDeviceParametersProvider
    implements LoginDeviceParametersProvider {
  @override
  Future<LoginDeviceParameters> load() async {
    return const LoginDeviceParameters(
      deviceUuid: 'device-uuid',
      deviceName: 'Google',
      deviceModel: 'Pixel 9/tokay',
      systemVersion: '15',
    );
  }
}
```

4. Build the route with the fake:

```dart
GoRoute(
  path: '/login',
  builder: (context, state) => LoginPage(
    deviceParametersProvider: _FakeLoginDeviceParametersProvider(),
  ),
),
```

5. Enter values that prove trim and password preservation:

```dart
await tester.enterText(fields.at(0), '  masked-user@example.invalid  ');
await tester.enterText(fields.at(1), '  ********  ');
```

6. Assert the exact multipart map:

```dart
expect(fieldsMap, {
  'device_uuid': 'device-uuid',
  'device_name': 'Google',
  'device_model': 'Pixel 9/tokay',
  'platform': 'android',
  'system_version': '15',
  'app_channel': 'official',
  'app_version': 'official',
  'app_version_number': '1.9.35',
  'username': 'masked-user@example.invalid',
  'password': '  ********  ',
});
```

- [ ] **Step 2: Run the widget test to verify RED**

Run:

```bash
flutter test test/features/auth/login_screen_test.dart
```

Expected: FAIL because `LoginPage` does not yet accept
`deviceParametersProvider` and still sends legacy hardcoded fields.

- [ ] **Step 3: Implement the minimal LoginPage integration**

Modify `lib/features/auth/screens/login_screen.dart`:

1. Remove imports for `StorageKeys` and `SharedPreferences`.
2. Add:

```dart
import 'package:jade/core/device/login_device_info_service.dart';
```

3. Extend the widget constructor without breaking existing routes:

```dart
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.deviceParametersProvider});

  final LoginDeviceParametersProvider? deviceParametersProvider;

  @override
  State<LoginPage> createState() => _LoginPageState();
}
```

4. Delete `_getDeviceUuid()`.
5. Before `api.post`, resolve the provider and load parameters:

```dart
final deviceProvider =
    widget.deviceParametersProvider ??
    await LoginDeviceInfoService.createDefault();
final deviceParameters = await deviceProvider.load();
```

6. Replace the old `FormData.fromMap` payload with:

```dart
data: FormData.fromMap({
  'username': _emailCtrl.text.trim(),
  'password': _passCtrl.text,
  ...deviceParameters.toMap(),
}),
```

Do not change login state transitions, authentication storage, error handling,
or navigation.

- [ ] **Step 4: Format and verify GREEN**

Run:

```bash
dart format lib/features/auth/screens/login_screen.dart test/features/auth/login_screen_test.dart
flutter test test/features/auth/login_screen_test.dart
flutter test test/core/device/login_device_info_service_test.dart
```

Expected: both test files PASS.

- [ ] **Step 5: Commit the login integration**

```bash
git add lib/features/auth/screens/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "fix(auth): send official Android login parameters"
```

### Task 3: Regression and static verification

**Files:**

- Verify only; no planned source changes.

**Interfaces:**

- Consumes the completed core service and LoginPage integration.
- Produces evidence that auth behavior and repository analysis remain clean.

- [ ] **Step 1: Run the focused auth regression suite**

Run:

```bash
flutter test test/features/auth test/core/providers/auth_provider_test.dart test/core/router/app_router_auth_test.dart
```

Expected: all auth page, provider, and auth-router tests PASS.

- [ ] **Step 2: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: exit code 0 with no analyzer errors or warnings introduced by this change.
If Flutter fails only because `/opt/homebrew/share/flutter/bin/cache` is not writable,
rerun with the required environment permission and preserve the exact output.

- [ ] **Step 3: Run the full test suite**

Run:

```bash
flutter test
```

Expected: all repository tests PASS.

- [ ] **Step 4: Confirm scoped repository state**

Run:

```bash
git status --short
git log -3 --oneline
```

Expected: no uncommitted implementation files remain; the two implementation
commits follow the previously committed design and plan documents.
