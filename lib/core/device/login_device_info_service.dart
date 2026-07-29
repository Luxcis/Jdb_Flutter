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

final class DeviceInfoPlusAndroidSource implements AndroidDeviceSnapshotSource {
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

final class LoginDeviceInfoService implements LoginDeviceParametersProvider {
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
