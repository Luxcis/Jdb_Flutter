import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/utils/user_facing_error.dart';

DioException _dioError(DioExceptionType type, {Object? error}) {
  return DioException(
    requestOptions: RequestOptions(path: '/api/v1/test'),
    type: type,
    error: error,
  );
}

void main() {
  group('userFacingErrorMessage', () {
    test('ApiException 优先使用服务端中文 message', () {
      const error = ApiException(
        action: ApiErrorActions.parameterInvalid,
        message: '账号或密码错误',
      );

      expect(userFacingErrorMessage(error), '账号或密码错误');
    });

    test('ApiException 无 message 时按 action 回退为中文提示', () {
      expect(
        userFacingErrorMessage(
          const ApiException(action: ApiErrorActions.parameterInvalid),
        ),
        '请求参数有误，请稍后重试',
      );
      expect(
        userFacingErrorMessage(
          const ApiException(action: ApiErrorActions.invalidSignature),
        ),
        '请求校验失败，请稍后重试',
      );
      expect(
        userFacingErrorMessage(
          const ApiException(action: ApiErrorActions.jwtVerificationError),
        ),
        '登录状态已失效，请重新登录',
      );
    });

    test('DioException.error 包装的 ApiException 同样使用服务端 message', () {
      final error = _dioError(
        DioExceptionType.badResponse,
        error: const ApiException(
          action: ApiErrorActions.parameterInvalid,
          message: '该邮箱已注册',
        ),
      );

      expect(userFacingErrorMessage(error), '该邮箱已注册');
      expect(userFacingApiException(error)?.message, '该邮箱已注册');
    });

    test('连接错误与各类超时统一提示网络连接失败', () {
      const types = [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ];

      for (final type in types) {
        expect(
          userFacingErrorMessage(_dioError(type)),
          '网络连接失败，请检查网络',
          reason: '$type',
        );
      }
    });

    test('其余 DioException 与普通异常不暴露英文技术串', () {
      expect(
        userFacingErrorMessage(_dioError(DioExceptionType.badResponse)),
        '加载失败，请重试',
      );
      expect(
        userFacingErrorMessage(StateError('controller not initialized')),
        '加载失败，请重试',
      );
      expect(
        userFacingErrorMessage(FormatException('unexpected token')),
        '加载失败，请重试',
      );
      expect(
        userFacingErrorMessage(Exception('DioException [bad response]')),
        '加载失败，请重试',
      );
    });

    test('空白 message 视为缺失并回退', () {
      const error = ApiException(
        action: ApiErrorActions.parameterInvalid,
        message: '   ',
      );

      expect(userFacingErrorMessage(error), '请求参数有误，请稍后重试');
    });

    test('非 ApiException 返回 null', () {
      expect(
        userFacingApiException(_dioError(DioExceptionType.connectionError)),
        isNull,
      );
      expect(userFacingApiException(StateError('boom')), isNull);
    });
  });
}
