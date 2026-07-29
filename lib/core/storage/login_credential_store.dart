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

  Future<void> save({required String username, required String password});

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
    return SavedLoginCredentials(username: values[0], password: values[1]);
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
