import 'package:jade/core/storage/login_credential_store.dart';

/// 内存版 [SecureValueStore]，供 tests 注入使用。
class InMemorySecureValueStore implements SecureValueStore {
  final Map<String, String?> _values = {};

  String? operator [](String key) => _values[key];

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
