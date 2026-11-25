import 'package:dio/dio.dart';
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
  bool _lastErrorRetryable = false;
  List<String> _recentKeywords = const [];
  List<String> _recentMagnetKeywords = const [];

  StartupStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// 最近一次失败是否属于可重试类别（网络/超时/608）。
  ///
  /// 解码或配置类错误即使重试也会得到同样结果，调用方可据此决定是否引导
  /// 用户继续重试。
  bool get lastErrorRetryable => _lastErrorRetryable;

  List<String> get recentKeywords => _recentKeywords;
  List<String> get recentMagnetKeywords => _recentMagnetKeywords;

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

    // 启动客户端支持轮换时，从本地持久化的可用线路开始逐个尝试。
    final rotator = _startupApi is StartupDomainRotator
        ? _startupApi as StartupDomainRotator
        : null;
    rotator?.resetCandidates(_domainManager.candidateBaseUrls);

    while (true) {
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
        _recentKeywords = List<String>.unmodifiable(startup.recentKeywords);
        _recentMagnetKeywords = List<String>.unmodifiable(
          startup.recentMagnetKeywords,
        );
        _lastErrorRetryable = false;
        _status = StartupStatus.success;
        notifyListeners();
        return true;
      } catch (error, stackTrace) {
        final retryable = _isRetryableFailure(error);
        if (retryable && rotator != null && rotator.useNextDomain()) {
          debugPrint('启动请求失败，改用候选线路 ${rotator.currentBaseUrl}: $error');
          continue;
        }
        _lastErrorRetryable = retryable;
        debugPrint('启动失败: $error\n$stackTrace');
        _status = StartupStatus.failure;
        _errorMessage = failureMessage;
        notifyListeners();
        return false;
      }
    }
  }

  Future<bool> retry() => load();

  /// 轮换候选域名只对「换一条线路可能成功」的错误有意义：连接级错误、
  /// 超时与 608（线路被封）。
  static bool _isRetryableFailure(Object error) {
    if (error is! DioException) return false;
    if (error.response?.statusCode == 608) return true;
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => true,
      _ => false,
    };
  }
}
