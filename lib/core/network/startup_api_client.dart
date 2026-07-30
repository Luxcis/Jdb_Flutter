import 'package:dio/dio.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/interceptors/response_interceptor.dart';
import 'package:jade/core/network/interceptors/response_logging_interceptor.dart';
import 'package:jade/core/network/interceptors/signature_interceptor.dart';

abstract interface class StartupApi {
  Future<StartupData> fetchStartup();
}

class StartupApiClient implements StartupApi {
  StartupApiClient._(this._dio);

  final Dio _dio;

  static StartupApiClient create() {
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
    return StartupApiClient._(dio);
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
