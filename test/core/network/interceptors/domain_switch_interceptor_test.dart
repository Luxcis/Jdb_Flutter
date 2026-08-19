import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/interceptors/domain_switch_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';

class _CaptureHandler extends ErrorInterceptorHandler {
  _CaptureHandler({this.onNext});
  final void Function(DioException)? onNext;

  @override
  void next(DioException err) {
    onNext?.call(err);
  }

  @override
  void resolve(Response response) {}

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('608 触发 rotate 并自动重试成功', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    final adapter = FakeAdapter();
    // 同路径先返回 608，再返回 200
    adapter.enqueueSequence('/x', [
      {'success': 0, 'action': 'Blocked'},
      {'success': 1, 'data': {'ok': true}},
    ], codes: [608, 200]);
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter;
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    dio.interceptors.add(ic);
    var rotated = false;
    ic.onRotated = () => rotated = true;
    // 发起请求触发 608 → 拦截器 rotate → 用新 baseUrl 重试 → 200
    final resp = await dio.get('/x');
    expect(resp.data, {'success': 1, 'data': {'ok': true}});
    expect(rotated, isTrue);
    expect(dm.currentUrl, 'https://b.com');
  });

  test('无备用域名时不重试，handler.next 原错误', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs); // 无 apiDomains
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = FakeAdapter();
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    var errPassed = false;
    final err = DioException(
      requestOptions: RequestOptions(path: '/x'),
      response:
          Response(requestOptions: RequestOptions(path: '/x'), statusCode: 608),
      type: DioExceptionType.badResponse,
    );
    ic.onError(err, _CaptureHandler(onNext: (e) => errPassed = true));
    // async handler — wait
    await Future.delayed(Duration.zero);
    expect(errPassed, isTrue);
  });

  test('manual 模式 608 不触发轮转', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    await dm.select('https://b.com');
    final adapter = FakeAdapter();
    adapter.enqueueSequence('/x', [
      {'success': 0, 'action': 'Blocked'},
    ], codes: [608]);
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter;
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    dio.interceptors.add(ic);
    var rotated = false;
    ic.onRotated = () => rotated = true;
    await expectLater(dio.get('/x'), throwsA(isA<DioException>()));
    expect(rotated, isFalse);
    expect(dm.currentUrl, 'https://b.com');
  });

  test('连接错误（SocketException）触发 rotate 并自动重试成功', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    final adapter = FakeAdapter();
    // 同一路径先抛连接错误，再返回 200（轮转后重试）
    adapter.enqueueSequence('/x', [
      {'success': 0, 'message': 'no stub'},
    ], codes: [500]);
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter;
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    dio.interceptors.add(ic);
    var rotated = false;
    ic.onRotated = () => rotated = true;

    // 直接构造连接错误（模拟 Connection reset by peer）
    final err = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
      error: const SocketException('Connection reset by peer'),
    );
    ic.onError(err, _CaptureHandler(onNext: (_) {}));

    await Future.delayed(Duration.zero);
    expect(rotated, isTrue);
    expect(dm.currentUrl, 'https://b.com');
  });

  test('连接错误无备用域名时不轮转，handler.next 原错误', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs); // 无 apiDomains
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = FakeAdapter();
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    var errPassed = false;
    final err = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
      error: const SocketException('Connection reset by peer'),
    );
    ic.onError(err, _CaptureHandler(onNext: (e) => errPassed = true));
    await Future.delayed(Duration.zero);
    expect(errPassed, isTrue);
  });

  test('端到端：连接错误触发 rotate 并用新 baseUrl 重试成功', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(BackupDomains(
      apiDomains: ['https://jdforrepam.com', 'https://b.com'],
    ));
    final adapter = FakeAdapter();
    // 第一次请求抛连接错误，重试（新 baseUrl）返回 200
    adapter
      ..throwFirst(
        '/x',
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/x'),
          reason: 'Connection reset by peer',
          error: const SocketException('Connection reset by peer'),
        ),
      )
      ..enqueue('/x', {'success': 1, 'data': {'ok': true}});
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter;
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    dio.interceptors.add(ic);
    var rotated = false;
    ic.onRotated = () => rotated = true;

    final resp = await dio.get('/x');

    expect(resp.data, {'success': 1, 'data': {'ok': true}});
    expect(rotated, isTrue);
    expect(dm.currentUrl, 'https://b.com');
    // 两次请求：第一次走原 baseUrl，重试走新 baseUrl
    expect(adapter.requests, hasLength(2));
    expect(
      adapter.requests.first.uri.toString(),
      startsWith('https://jdforrepam.com'),
    );
    expect(
      adapter.requests.last.uri.toString(),
      startsWith('https://b.com'),
    );
  });
}
