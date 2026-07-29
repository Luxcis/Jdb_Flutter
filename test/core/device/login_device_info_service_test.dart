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
    expect(generator.lastNamespace, '6ba7b812-9dad-11d1-80b4-00c04fd430c8');
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
  _FakeGenerator({this.v4Result = 'fake-v4', this.v5Result = 'fake-v5'});

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
