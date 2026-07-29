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
