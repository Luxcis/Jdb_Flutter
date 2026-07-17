import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_exception.dart';

void main() {
  test('ApiException 携带 action 与 message', () {
    final e = ApiException.fromAction(
      ApiErrorActions.jwtVerificationError,
      '請登錄帳號',
    );
    expect(e.action, ApiErrorActions.jwtVerificationError);
    expect(e.message, '請登錄帳號');
    expect(e.isAuthError, isTrue);
  });

  test('非鉴权 action 的 isAuthError 为 false', () {
    final e = ApiException.fromAction(
      ApiErrorActions.parameterInvalid,
      '參數不能爲空: q',
    );
    expect(e.isAuthError, isFalse);
  });
}
