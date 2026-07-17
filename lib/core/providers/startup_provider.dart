// lib/core/providers/startup_provider.dart
import 'package:flutter/foundation.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';

class StartupProvider extends ChangeNotifier {
  StartupProvider._(this._api, this._dm);
  final ApiClient _api;
  final DomainManager _dm;
  bool _loaded = false;
  bool get loaded => _loaded;

  static StartupProvider create(ApiClient api, DomainManager dm) =>
      StartupProvider._(api, dm);

  /// 调 /startup 拉取并应用域名列表。
  Future<void> fetchStartup() async {
    try {
      final resp = await _api.get(Endpoints.startup, queryParameters: {
        'platform': 'android',
        'app_channel': 'google',
        'app_version': '1.9.29',
        'app_version_number': '35',
      });
      final data = (resp.data as Map?)?['backup_domains_data'] as String?;
      final domains = _tryDecodeDomains(data);
      await _dm.applyStartup(domains);
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // 失败保留当前域名，不阻断启动。
    }
  }

  BackupDomains _tryDecodeDomains(String? data) {
    // 简化：返回仅含主域名的兜底列表；完整解密在后续阶段。
    return const BackupDomains(apiDomains: ['https://jdforrepam.com']);
  }
}
