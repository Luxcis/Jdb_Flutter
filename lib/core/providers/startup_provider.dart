import 'package:flutter/foundation.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/backup_domains_decryptor.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/startup_api_client.dart';

enum StartupStatus { idle, loading, success, failure }

typedef StartupDomainsDecoder = BackupDomains Function(String data);

class StartupProvider extends ChangeNotifier {
  StartupProvider._({
    required StartupApi startupApi,
    required ApiClient apiClient,
    required DomainManager domainManager,
    required StartupDomainsDecoder decoder,
  }) : _startupApi = startupApi,
       _apiClient = apiClient,
       _domainManager = domainManager,
       _decoder = decoder;

  static const String failureMessage = '启动失败，请检查网络后重试';

  final StartupApi _startupApi;
  final ApiClient _apiClient;
  final DomainManager _domainManager;
  final StartupDomainsDecoder _decoder;

  StartupStatus _status = StartupStatus.idle;
  String? _errorMessage;

  StartupStatus get status => _status;
  String? get errorMessage => _errorMessage;

  static StartupProvider create({
    required StartupApi startupApi,
    required ApiClient apiClient,
    required DomainManager domainManager,
    StartupDomainsDecoder decoder = BackupDomainsDecryptor.decrypt,
  }) {
    return StartupProvider._(
      startupApi: startupApi,
      apiClient: apiClient,
      domainManager: domainManager,
      decoder: decoder,
    );
  }

  Future<bool> load() async {
    if (_status == StartupStatus.loading) {
      return false;
    }
    _status = StartupStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final startup = await _startupApi.fetchStartup();
      final encoded = startup.backupDomainsData;
      if (encoded == null || encoded.isEmpty) {
        throw const FormatException('Missing backup_domains_data');
      }
      final domains = _decoder(encoded);
      if (domains.apiDomains.isEmpty) {
        throw const FormatException('Empty apiDomains');
      }
      await _domainManager.applyStartup(domains);
      _apiClient.swapBaseUrl(_domainManager.currentUrl);
      _status = StartupStatus.success;
      notifyListeners();
      return true;
    } catch (_) {
      _status = StartupStatus.failure;
      _errorMessage = failureMessage;
      notifyListeners();
      return false;
    }
  }

  Future<bool> retry() => load();
}
