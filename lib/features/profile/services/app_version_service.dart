import 'package:package_info_plus/package_info_plus.dart';

abstract interface class AppVersionService {
  Future<String> loadVersion();
}

final class PackageAppVersionService implements AppVersionService {
  const PackageAppVersionService();

  @override
  Future<String> loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}
