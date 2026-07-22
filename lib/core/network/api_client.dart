// lib/core/network/api_client.dart
import 'package:dio/dio.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/interceptors/auth_interceptor.dart';
import 'package:jade/core/network/interceptors/domain_switch_interceptor.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/interceptors/response_logging_interceptor.dart';
import 'package:jade/core/network/interceptors/signature_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token 提供者抽象（AuthProvider 实现）。
abstract class TokenProvider {
  String? get token;
}

class ApiClient {
  ApiClient._({required this.dio, required this.domainManager});

  late final Dio dio;
  final DomainManager domainManager;

  static ApiClient? _instance;
  static ApiClient get instance => _instance!;
  static ApiClient? get instanceOrNull => _instance;

  static Future<ApiClient> create({
    required SharedPreferences prefs,
    required TokenProvider tokenProvider,
    required void Function() onAuthError,
  }) async {
    final dm = await DomainManager.load(prefs);
    final dio = Dio(
      BaseOptions(
        baseUrl: dm.currentUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    dio.interceptors.addAll([
      SignatureInterceptor(),
      AuthInterceptor(tokenProvider),
      ResponseLoggingInterceptor(),
      ResponseInterceptor(onAuthError: onAuthError),
      DomainSwitchInterceptor(domainManager: dm, dio: dio),
    ]);
    final client = ApiClient._(dio: dio, domainManager: dm);
    _instance = client;
    return client;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return dio.post(path, data: data);
  }

  /// 手动切换 baseUrl（用于设置页线路切换）。
  void swapBaseUrl(String url) {
    dio.options.baseUrl = url;
  }

  /// 测试注入。
  void setAdapterForTest(HttpClientAdapter adapter) {
    dio.httpClientAdapter = adapter;
  }

  /// 测试用工厂：轻量 ApiClient（无单例、无拦截器链）。
  /// 调用方负责注入 [FakeAdapter] 和装配 [ResponseInterceptor]。
  factory ApiClient.forTest({
    required Dio dio,
    required DomainManager domainManager,
  }) = ApiClient._;
}
