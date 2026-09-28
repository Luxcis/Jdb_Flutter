import 'package:dio/dio.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';

/// 认证会话数据服务：登录、注册取数统一入口（screen 不再直接触碰 ApiClient）。
class AuthSessionService {
  AuthSessionService(this._api);

  final ApiClient _api;

  /// ApiClient 未初始化时返回 null（页面据此保持原有静默降级行为）。
  static AuthSessionService? resolve() => switch (ApiClient.instanceOrNull) {
    final api? => AuthSessionService(api),
    null => null,
  };

  /// 使用官方 multipart 参数发起登录，返回接口 `data`
  /// 字段（token / user / following_tags）。
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required Map<String, dynamic> deviceParameters,
  }) async {
    final resp = await _api.post(
      Endpoints.sessions,
      data: FormData.fromMap({
        'username': username,
        'password': password,
        ...deviceParameters,
      }),
    );
    return Map<String, dynamic>.from(resp.data as Map);
  }

  /// 发起注册请求。请求体沿用既有契约字段（历史硬编码设备信息不变）。
  Future<void> register({
    required String email,
    required String password,
    required String deviceUuid,
  }) async {
    await _api.post(
      Endpoints.users,
      data: {
        'email': email,
        'username': email,
        'password': password,
        'device_uuid': deviceUuid,
        'device_name': 'Jade',
        'device_model': 'Flutter',
        'platform': 'android',
        'system_version': '14',
        'app_channel': 'google',
        'app_version': '1.9.29',
        'app_version_number': '35',
      },
    );
  }
}
