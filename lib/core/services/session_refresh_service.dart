import 'package:dio/dio.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';

/// 会话刷新结果。
enum SessionRefreshStatus {
  /// 校验成功，缓存已用最新用户信息刷新。
  success,

  /// 鉴权失败（token 过期/用户不存在），会话已登出。
  expired,

  /// 未登录，跳过校验。
  skipped,

  /// 网络或服务端错误，保留原会话。
  failure,
}

/// 进入应用时校验登录会话并刷新用户缓存。
abstract interface class SessionRefreshService {
  /// 校验当前会话；已登录则调用用户信息接口，按结果更新缓存或登出。
  Future<SessionRefreshStatus> refresh();
}

/// 基于 [AuthProvider] 与 [TokenAuthenticationService] 的默认实现。
final class ApiSessionRefreshService implements SessionRefreshService {
  ApiSessionRefreshService({
    required AuthProvider auth,
    required TokenAuthenticationService tokenAuthentication,
  }) : _auth = auth,
       _tokenAuthentication = tokenAuthentication;

  final AuthProvider _auth;
  final TokenAuthenticationService _tokenAuthentication;

  @override
  Future<SessionRefreshStatus> refresh() async {
    final token = _auth.token;
    if (token == null || token.isEmpty) {
      return SessionRefreshStatus.skipped;
    }
    try {
      final user = await _tokenAuthentication.authenticate(token);
      await _auth.updateUser(user);
      return SessionRefreshStatus.success;
    } on ApiException catch (error) {
      if (error.isAuthError) {
        await _logoutBestEffort();
        return SessionRefreshStatus.expired;
      }
      return SessionRefreshStatus.failure;
    } on DioException catch (error) {
      final cause = error.error;
      if (error.response?.statusCode == 401 ||
          (cause is ApiException && cause.isAuthError)) {
        await _logoutBestEffort();
        return SessionRefreshStatus.expired;
      }
      return SessionRefreshStatus.failure;
    } catch (_) {
      return SessionRefreshStatus.failure;
    }
  }

  Future<void> _logoutBestEffort() async {
    try {
      await _auth.logout();
    } catch (_) {
      // 登出持久化失败时尽力而为，仍返回 expired 由 UI 引导重登。
    }
  }
}
