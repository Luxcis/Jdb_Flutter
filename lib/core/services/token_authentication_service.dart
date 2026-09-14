import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';

abstract interface class TokenAuthenticationService {
  Future<Map<String, dynamic>> authenticate(String token);
}

final class ApiTokenAuthenticationService
    implements TokenAuthenticationService {
  const ApiTokenAuthenticationService(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> authenticate(String token) async {
    final response = await _api.getWithCandidateToken(
      Endpoints.users,
      token: token,
    );
    final entity = response.data;
    if (entity is Map) {
      final user = entity['user'];
      if (user is Map && user.isNotEmpty) {
        return Map<String, dynamic>.from(user);
      }
    }
    throw const FormatException('用户信息格式无效');
  }
}
