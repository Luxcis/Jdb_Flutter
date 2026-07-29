# Secure Login Credential Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Securely remember the last successful login credentials, refill the login form after token expiry, and remove only the saved password on explicit logout.

**Architecture:** Add a core `LoginCredentialStore` interface with a `flutter_secure_storage` production adapter and injectable test fakes. `LoginPage` restores and saves credentials without exposing passwords to `AuthProvider`; `ProfilePage` clears only the saved password before completing explicit logout.

**Tech Stack:** Flutter, Dart 3.8+, `flutter_secure_storage ^10.3.1`, Android Keystore, Provider, GoRouter, `flutter_test`

## Global Constraints

- Store username and password only in `flutter_secure_storage`, never in `SharedPreferences`.
- Raise Android `minSdk` to exactly 23.
- Set `android:allowBackup="false"` on the Android application to prevent restored ciphertext from losing its device-bound key.
- Save credentials only after the server has accepted the login.
- Save `username.trim()` and the password input unchanged.
- Never store credentials after a failed login.
- Token expiry clears token/user but preserves both saved credential fields.
- Explicit logout clears only the saved password and preserves the saved username.
- Restoring credentials fills the form but never submits it.
- An asynchronous restore must not overwrite a field the user has already edited.
- Secure-storage read, write, or delete failures must not block manual login, a successful authenticated session, or explicit logout.
- Never log credential values or place real credentials in documentation/tests.
- Do not change login request fields, device parameters, signatures, registration, or token lifetime.

---

## File Map

- Create `lib/core/storage/login_credential_store.dart`: credential model and interfaces, secure-storage adapter, key mapping, save/read/password-delete behavior.
- Create `test/core/storage/login_credential_store_test.dart`: unit coverage against an in-memory secure key-value fake.
- Modify `pubspec.yaml` and `pubspec.lock`: add `flutter_secure_storage ^10.3.1`.
- Modify `android/app/build.gradle.kts`: set `minSdk = 23`.
- Modify `android/app/src/main/AndroidManifest.xml`: set `android:allowBackup="false"`.
- Modify `lib/features/auth/screens/login_screen.dart`: restore fields, preserve user edits, save only after server success, and tolerate secure-storage failures.
- Modify `test/features/auth/login_screen_test.dart`: cover restore, no auto-submit, edit race, successful save, failed login, and storage errors.
- Modify `lib/features/profile/screens/profile_screen.dart`: clear only the password on explicit logout while always clearing the auth session.
- Create `test/features/profile/profile_screen_test.dart`: verify explicit logout success and delete-failure behavior.

### Task 1: Secure credential storage and Android configuration

**Files:**

- Create: `lib/core/storage/login_credential_store.dart`
- Create: `test/core/storage/login_credential_store_test.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**

- Produces: `SavedLoginCredentials({String? username, String? password})`
- Produces: `LoginCredentialStore.read(): Future<SavedLoginCredentials>`
- Produces: `LoginCredentialStore.save({required String username, required String password}): Future<void>`
- Produces: `LoginCredentialStore.clearPassword(): Future<void>`
- Produces: `SecureValueStore.read(String key): Future<String?>`
- Produces: `SecureValueStore.write(String key, String value): Future<void>`
- Produces: `SecureValueStore.delete(String key): Future<void>`
- Produces: `SecureLoginCredentialStore.createDefault(): SecureLoginCredentialStore`

- [ ] **Step 1: Add the approved secure-storage dependency**

Run:

```bash
flutter pub add flutter_secure_storage:^10.3.1
```

Expected:

- `pubspec.yaml` lists `flutter_secure_storage: ^10.3.1`.
- `pubspec.lock` resolves it as a direct main dependency.

- [ ] **Step 2: Write the failing credential-store tests**

Create `test/core/storage/login_credential_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/storage/login_credential_store.dart';

void main() {
  test('无缓存时返回空凭据', () async {
    final store = SecureLoginCredentialStore(_MemorySecureValueStore());

    final credentials = await store.read();

    expect(credentials.username, isNull);
    expect(credentials.password, isNull);
  });

  test('保存后读取相同的用户名和密码', () async {
    final store = SecureLoginCredentialStore(_MemorySecureValueStore());

    await store.save(
      username: 'masked-user@example.invalid',
      password: 'test-password',
    );

    final credentials = await store.read();
    expect(credentials.username, 'masked-user@example.invalid');
    expect(credentials.password, 'test-password');
  });

  test('clearPassword 只删除密码并保留用户名', () async {
    final store = SecureLoginCredentialStore(_MemorySecureValueStore());
    await store.save(
      username: 'masked-user@example.invalid',
      password: 'test-password',
    );

    await store.clearPassword();

    final credentials = await store.read();
    expect(credentials.username, 'masked-user@example.invalid');
    expect(credentials.password, isNull);
  });
}

final class _MemorySecureValueStore implements SecureValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
```

Each test catches a consumer-visible storage regression: wrong key mapping,
failure to persist both values, or accidental username deletion.

- [ ] **Step 3: Run the store test to verify RED**

Run:

```bash
flutter test test/core/storage/login_credential_store_test.dart
```

Expected: FAIL because `login_credential_store.dart` and its public types do not exist.

- [ ] **Step 4: Implement the minimal secure credential store**

Create `lib/core/storage/login_credential_store.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _usernameKey = 'login_credential_username';
const _passwordKey = 'login_credential_password';

final class SavedLoginCredentials {
  const SavedLoginCredentials({this.username, this.password});

  final String? username;
  final String? password;
}

abstract interface class LoginCredentialStore {
  Future<SavedLoginCredentials> read();

  Future<void> save({
    required String username,
    required String password,
  });

  Future<void> clearPassword();
}

abstract interface class SecureValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class FlutterSecureValueStore implements SecureValueStore {
  FlutterSecureValueStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class SecureLoginCredentialStore implements LoginCredentialStore {
  SecureLoginCredentialStore(this._storage);

  factory SecureLoginCredentialStore.createDefault() =>
      SecureLoginCredentialStore(
        FlutterSecureValueStore(const FlutterSecureStorage()),
      );

  final SecureValueStore _storage;

  @override
  Future<SavedLoginCredentials> read() async {
    final values = await Future.wait([
      _storage.read(_usernameKey),
      _storage.read(_passwordKey),
    ]);
    return SavedLoginCredentials(
      username: values[0],
      password: values[1],
    );
  }

  @override
  Future<void> save({
    required String username,
    required String password,
  }) async {
    await _storage.write(_usernameKey, username);
    await _storage.write(_passwordKey, password);
  }

  @override
  Future<void> clearPassword() => _storage.delete(_passwordKey);
}
```

- [ ] **Step 5: Apply the approved Android security configuration**

In `android/app/build.gradle.kts`, replace the inherited minimum:

```kotlin
defaultConfig {
    applicationId = "xxx.porn.jdb"
    minSdk = 23
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
}
```

In `android/app/src/main/AndroidManifest.xml`, add backup protection:

```xml
<application
    android:allowBackup="false"
    android:label="@string/app_name"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
```

- [ ] **Step 6: Format and verify GREEN**

Run:

```bash
dart format lib/core/storage/login_credential_store.dart test/core/storage/login_credential_store_test.dart
flutter test test/core/storage/login_credential_store_test.dart
```

Expected: all three credential-store tests PASS.

- [ ] **Step 7: Commit the secure storage slice**

```bash
git add pubspec.yaml pubspec.lock android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml lib/core/storage/login_credential_store.dart test/core/storage/login_credential_store_test.dart
git commit -m "feat(auth): add secure login credential storage"
```

### Task 2: Restore and save credentials in LoginPage

**Files:**

- Modify: `lib/features/auth/screens/login_screen.dart`
- Modify: `test/features/auth/login_screen_test.dart`

**Interfaces:**

- Consumes: `LoginCredentialStore`
- Consumes: `SecureLoginCredentialStore.createDefault()`
- Preserves: `LoginPage({Key? key, LoginDeviceParametersProvider? deviceParametersProvider, LoginCredentialStore? credentialStore})`
- Produces: form restoration without automatic submission and successful-login persistence.

- [ ] **Step 1: Add a credential-store fake to the LoginPage test**

Add to `test/features/auth/login_screen_test.dart`:

```dart
import 'dart:async';

import 'package:jade/core/storage/login_credential_store.dart';

final class _MemoryLoginCredentialStore implements LoginCredentialStore {
  _MemoryLoginCredentialStore({
    this.credentials = const SavedLoginCredentials(),
    this.readFuture,
    this.readError,
    this.saveError,
  });

  SavedLoginCredentials credentials;
  final Future<SavedLoginCredentials>? readFuture;
  final Object? readError;
  final Object? saveError;
  var saveCalls = 0;

  @override
  Future<SavedLoginCredentials> read() async {
    if (readError case final error?) throw error;
    if (readFuture != null) return readFuture!;
    return credentials;
  }

  @override
  Future<void> save({
    required String username,
    required String password,
  }) async {
    saveCalls++;
    if (saveError case final error?) throw error;
    credentials = SavedLoginCredentials(
      username: username,
      password: password,
    );
  }

  @override
  Future<void> clearPassword() async {
    credentials = SavedLoginCredentials(username: credentials.username);
  }
}
```

Update the test route helper so every `LoginPage` receives both the existing
device fake and a supplied credential store:

```dart
LoginPage(
  deviceParametersProvider: _FakeLoginDeviceParametersProvider(),
  credentialStore: credentialStore,
)
```

- [ ] **Step 2: Write failing restore tests**

Add these Widget tests:

```dart
testWidgets('进入登录页自动填充已保存的用户名和密码但不自动登录', (tester) async {
  final store = _MemoryLoginCredentialStore(
    credentials: const SavedLoginCredentials(
      username: 'masked-user@example.invalid',
      password: 'test-password',
    ),
  );
  final subject = await _pumpLogin(tester, credentialStore: store);

  final fields = find.byType(TextField);
  expect(tester.widget<TextField>(fields.at(0)).controller!.text,
      'masked-user@example.invalid');
  expect(tester.widget<TextField>(fields.at(1)).controller!.text,
      'test-password');
  expect(subject.adapter.requests, isEmpty);
});

testWidgets('仅保存用户名时密码框保持为空', (tester) async {
  final store = _MemoryLoginCredentialStore(
    credentials: const SavedLoginCredentials(
      username: 'masked-user@example.invalid',
    ),
  );
  await _pumpLogin(tester, credentialStore: store);

  final fields = find.byType(TextField);
  expect(tester.widget<TextField>(fields.at(0)).controller!.text,
      'masked-user@example.invalid');
  expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
});

testWidgets('异步恢复完成时不覆盖用户已编辑的输入', (tester) async {
  final completer = Completer<SavedLoginCredentials>();
  final store = _MemoryLoginCredentialStore(readFuture: completer.future);
  await _pumpLogin(tester, credentialStore: store, settle: false);
  await tester.pump();

  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'typed-user');
  await tester.enterText(fields.at(1), 'typed-password');
  completer.complete(
    const SavedLoginCredentials(
      username: 'cached-user',
      password: 'cached-password',
    ),
  );
  await tester.pumpAndSettle();

  expect(tester.widget<TextField>(fields.at(0)).controller!.text, 'typed-user');
  expect(tester.widget<TextField>(fields.at(1)).controller!.text,
      'typed-password');
});

testWidgets('安全存储读取失败时保持空表单并允许手动输入', (tester) async {
  final store = _MemoryLoginCredentialStore(
    readError: StateError('secure read failed'),
  );
  await _pumpLogin(tester, credentialStore: store);

  final fields = find.byType(TextField);
  expect(tester.widget<TextField>(fields.at(0)).controller!.text, isEmpty);
  expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
  await tester.enterText(fields.at(0), 'typed-user');
  expect(find.text('typed-user'), findsOneWidget);
});
```

- [ ] **Step 3: Write failing save tests**

Extend the existing successful multipart test to inject the memory store and
assert:

```dart
expect(store.saveCalls, 1);
expect(store.credentials.username, 'masked-user@example.invalid');
expect(store.credentials.password, '  ********  ');
```

Add:

```dart
testWidgets('登录失败不覆盖已保存凭据', (tester) async {
  final original = const SavedLoginCredentials(
    username: 'cached-user',
    password: 'cached-password',
  );
  final store = _MemoryLoginCredentialStore(credentials: original);
  final subject = await _pumpLogin(
    tester,
    credentialStore: store,
    response: {'success': 0, 'message': '登录失败'},
  );

  await _submitCredentials(tester, 'new-user', 'new-password');

  expect(store.saveCalls, 0);
  expect(store.credentials.username, 'cached-user');
  expect(store.credentials.password, 'cached-password');
  expect(subject.auth.isLogged, isFalse);
});

testWidgets('凭据保存失败不回滚登录或阻止成功跳转', (tester) async {
  final store = _MemoryLoginCredentialStore(
    saveError: StateError('secure write failed'),
  );
  final subject = await _pumpLogin(tester, credentialStore: store);

  await _submitCredentials(tester, 'masked-user@example.invalid', 'password');

  expect(store.saveCalls, 1);
  expect(subject.auth.isLogged, isTrue);
  expect(subject.router.state.uri.path, '/home');
});
```

Use `_pumpLogin` to return a record containing the real `FakeAdapter`,
`AuthProvider`, and `GoRouter`; use `_submitCredentials` to enter text, tap
the login button, and settle. All expected credential literals remain
synthetic.

- [ ] **Step 4: Run LoginPage tests to verify RED**

Run:

```bash
flutter test test/features/auth/login_screen_test.dart
```

Expected: FAIL because `LoginPage` does not accept `credentialStore`, does not
restore values, and does not save successful credentials.

- [ ] **Step 5: Implement LoginPage restoration and persistence**

Modify `lib/features/auth/screens/login_screen.dart`:

```dart
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.deviceParametersProvider,
    this.credentialStore,
  });

  final LoginDeviceParametersProvider? deviceParametersProvider;
  final LoginCredentialStore? credentialStore;
  // ...
}
```

In state, initialize and restore without overwriting user edits:

```dart
late final LoginCredentialStore _credentialStore;
var _usernameEdited = false;
var _passwordEdited = false;

@override
void initState() {
  super.initState();
  _credentialStore =
      widget.credentialStore ?? SecureLoginCredentialStore.createDefault();
  _restoreCredentials();
}

Future<void> _restoreCredentials() async {
  try {
    final credentials = await _credentialStore.read();
    if (!mounted) return;
    final username = credentials.username;
    if (!_usernameEdited && username != null && username.isNotEmpty) {
      _emailCtrl.text = username;
    }
    final password = credentials.password;
    if (!_passwordEdited && password != null && password.isNotEmpty) {
      _passCtrl.text = password;
    }
  } catch (_) {
    // 安全存储不可用时保留当前输入，允许用户继续手动登录。
  }
}
```

Add user-edit markers:

```dart
TextField(
  controller: _emailCtrl,
  onChanged: (_) => _usernameEdited = true,
  // existing properties...
)

TextField(
  controller: _passCtrl,
  onChanged: (_) => _passwordEdited = true,
  // existing properties...
)
```

After the server response has yielded token/user, save credentials without
blocking authentication:

```dart
final username = _emailCtrl.text.trim();
final password = _passCtrl.text;

// Use username/password in FormData.

try {
  await _credentialStore.save(username: username, password: password);
} catch (_) {
  // 服务端登录已成功，安全存储失败不能回滚认证。
}
if (!mounted) return;
await context.read<AuthProvider>().login(token: token, user: user);
```

Do not place the storage call before the successful server response.

- [ ] **Step 6: Format and verify GREEN**

Run:

```bash
dart format lib/features/auth/screens/login_screen.dart test/features/auth/login_screen_test.dart
flutter test test/features/auth/login_screen_test.dart
flutter test test/core/storage/login_credential_store_test.dart
```

Expected: all LoginPage and credential-store tests PASS.

- [ ] **Step 7: Commit the LoginPage slice**

```bash
git add lib/features/auth/screens/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "feat(auth): restore and save login credentials"
```

### Task 3: Clear only the password on explicit logout

**Files:**

- Modify: `lib/features/profile/screens/profile_screen.dart`
- Create: `test/features/profile/profile_screen_test.dart`

**Interfaces:**

- Consumes: `LoginCredentialStore.clearPassword(): Future<void>`
- Preserves: token-expiry path in `main.dart`, which continues to call only `AuthProvider.logout()`.
- Produces: `ProfilePage({Key? key, LoginCredentialStore? credentialStore})`.

- [ ] **Step 1: Write failing explicit-logout Widget tests**

Create `test/features/profile/profile_screen_test.dart` with a real
`AuthProvider`, a GoRouter, and an in-memory credential store:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/login_credential_store.dart';
import 'package:jade/features/profile/screens/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('主动退出删除密码但保留用户名并清除会话', (tester) async {
    final subject = await _pumpProfile(tester);

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(subject.store.credentials.username,
        'masked-user@example.invalid');
    expect(subject.store.credentials.password, isNull);
    expect(subject.auth.isLogged, isFalse);
    expect(subject.router.state.uri.path, '/home');
  });

  testWidgets('密码删除失败时仍清除会话并返回首页', (tester) async {
    final subject = await _pumpProfile(
      tester,
      clearError: StateError('secure delete failed'),
    );

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(subject.store.clearCalls, 1);
    expect(subject.auth.isLogged, isFalse);
    expect(subject.router.state.uri.path, '/home');
  });
}
```

Implement `_pumpProfile` locally to:

- initialize empty `SharedPreferences`;
- create and log in a real `AuthProvider`;
- create a fake `LoginCredentialStore` containing synthetic username/password;
- route `/profile` to `ProfilePage(credentialStore: store)` and `/home` to an
  empty widget;
- return `(auth: auth, store: store, router: router)`.

The fake's `clearPassword()` increments `clearCalls`, optionally throws
`clearError`, and otherwise replaces credentials with username-only data.

- [ ] **Step 2: Run profile tests to verify RED**

Run:

```bash
flutter test test/features/profile/profile_screen_test.dart
```

Expected: FAIL because `ProfilePage` does not accept a credential store and
explicit logout only calls `AuthProvider.logout()`.

- [ ] **Step 3: Implement password-only clearing on explicit logout**

Modify `lib/features/profile/screens/profile_screen.dart`:

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.credentialStore});

  final LoginCredentialStore? credentialStore;
  // ...
}
```

Replace the explicit logout callback:

```dart
onTap: () async {
  final store =
      credentialStore ?? SecureLoginCredentialStore.createDefault();
  try {
    await store.clearPassword();
  } catch (_) {
    // 密码缓存删除失败不能阻止会话退出。
  }
  await auth.logout();
  if (context.mounted) context.go('/home');
},
```

Do not change `main.dart`: token expiry must continue to preserve both
credential fields.

- [ ] **Step 4: Format and verify GREEN**

Run:

```bash
dart format lib/features/profile/screens/profile_screen.dart test/features/profile/profile_screen_test.dart
flutter test test/features/profile/profile_screen_test.dart
flutter test test/features/auth/login_screen_test.dart
flutter test test/core/providers/auth_provider_test.dart test/core/router/app_router_auth_test.dart
```

Expected: profile, login, provider, and auth-router tests all PASS.

- [ ] **Step 5: Commit the explicit-logout slice**

```bash
git add lib/features/profile/screens/profile_screen.dart test/features/profile/profile_screen_test.dart
git commit -m "fix(auth): clear saved password on explicit logout"
```

### Task 4: Static, full-suite, and Android verification

**Files:**

- Verify only; no planned source changes.

**Interfaces:**

- Consumes all completed credential-cache slices.
- Produces fresh evidence for Dart, Flutter, and Android configuration.

- [ ] **Step 1: Run the focused authentication suite**

Run:

```bash
flutter test test/core/storage/login_credential_store_test.dart test/features/auth test/features/profile/profile_screen_test.dart test/core/providers/auth_provider_test.dart test/core/router/app_router_auth_test.dart
```

Expected: all focused credential, login, explicit-logout, provider, and
auth-router tests PASS.

- [ ] **Step 2: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: exit code 0 and `No issues found`.

- [ ] **Step 3: Verify Android debug compilation**

Run:

```bash
flutter build apk --debug
```

Expected: the Android build succeeds with `minSdk = 23`, the secure-storage
plugin registers, and an APK is produced.

- [ ] **Step 4: Run the full Flutter test suite**

Run:

```bash
flutter test
```

Expected: all repository tests PASS.

- [ ] **Step 5: Confirm scoped repository state**

Run:

```bash
git status --short
git log -6 --oneline
```

Expected: no uncommitted credential-cache implementation files remain, and
the three implementation commits follow the design and plan commits.
