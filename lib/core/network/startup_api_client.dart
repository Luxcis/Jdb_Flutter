import 'package:dio/dio.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/interceptors/response_logging_interceptor.dart';
import 'package:jade/core/network/interceptors/signature_interceptor.dart';

abstract interface class StartupApi {
  Future<StartupData> fetchStartup();
}

/// 启动阶段可轮换候选线路的客户端能力。
///
/// [StartupProvider] 通过它把「持久化可用线路 → 备用域名 → 兜底域名」的候选
/// 列表注入启动客户端，并在请求失败时逐个尝试。
abstract interface class StartupDomainRotator {
  /// 以 [candidates] 作为本次启动的候选线路并回到第一个候选（通常是本地
  /// 持久化的可用线路）。
  ///
  /// 返回 false 表示没有合规候选，当前 baseUrl 保持不变。
  bool resetCandidates(List<String> candidates);

  /// 切换到下一个候选线路；返回 false 表示候选已耗尽。
  bool useNextDomain();

  /// 当前正在使用的启动线路。
  String get currentBaseUrl;
}

class StartupApiClient implements StartupApi, StartupDomainRotator {
  StartupApiClient._(this._dio);

  final Dio _dio;
  List<String> _candidates = const [AppConstants.fallbackBaseUrl];
  int _index = 0;

  /// [candidateBaseUrls] 为可选的首批候选线路；缺省时只使用兜底域名，
  /// 由 [StartupDomainRotator.resetCandidates] 在启动时注入完整候选列表。
  static StartupApiClient create({List<String>? candidateBaseUrls}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.fallbackBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    dio.interceptors.addAll([
      SignatureInterceptor(),
      ResponseLoggingInterceptor(),
      ResponseInterceptor(onAuthError: () {}),
    ]);
    final client = StartupApiClient._(dio);
    client.resetCandidates(candidateBaseUrls ?? const []);
    return client;
  }

  @override
  String get currentBaseUrl => _candidates[_index];

  @override
  bool resetCandidates(List<String> candidates) {
    final valid = DomainManager.validBaseUrls(candidates);
    if (valid.isEmpty) return false;
    _candidates = List.unmodifiable(valid);
    _index = 0;
    _dio.options.baseUrl = _candidates.first;
    return true;
  }

  @override
  bool useNextDomain() {
    if (_index + 1 >= _candidates.length) return false;
    _index += 1;
    _dio.options.baseUrl = _candidates[_index];
    return true;
  }

  @override
  Future<StartupData> fetchStartup() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.startup,
      queryParameters: const {
        'last_ad_id': '',
        'platform': 'android',
        'app_channel': 'google',
        'app_version': 'official',
        'app_version_number': '1.9.29',
      },
    );
    return StartupData.fromJson(response.data ?? const {});
  }

  void setAdapterForTest(HttpClientAdapter adapter) {
    _dio.httpClientAdapter = adapter;
  }
}
