import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/network/interceptors/domain_switch_interceptor.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';

/// 指定 host 恒定抛连接错误，其余 host 返回成功响应。
///
/// 用于并发场景：每次请求打到失效域名都失败，轮转后的重试则成功。
class _FailHostAdapter implements HttpClientAdapter {
  _FailHostAdapter({required this.failedHost, required this.body});

  final String failedHost;
  final Map<String, dynamic> body;
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    requests.add(uri);
    if (uri.host == failedHost) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection reset by peer',
        error: const SocketException('Connection reset by peer'),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {
    requests.clear();
  }
}

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
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('608 触发 rotate 并自动重试成功', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://b.com']),
    );
    final adapter = FakeAdapter();
    // 同路径先返回 608，再返回 200
    adapter.enqueueSequence(
      '/x',
      [
        {'success': 0, 'action': 'Blocked'},
        {
          'success': 1,
          'data': {'ok': true},
        },
      ],
      codes: [608, 200],
    );
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter;
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    dio.interceptors.add(ic);
    var rotated = false;
    ic.onRotated = () => rotated = true;
    // 发起请求触发 608 → 拦截器 rotate → 用新 baseUrl 重试 → 200
    final resp = await dio.get('/x');
    expect(resp.data, {
      'success': 1,
      'data': {'ok': true},
    });
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
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 608,
      ),
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
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://b.com']),
    );
    await dm.select('https://b.com');
    final adapter = FakeAdapter();
    adapter.enqueueSequence(
      '/x',
      [
        {'success': 0, 'action': 'Blocked'},
      ],
      codes: [608],
    );
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
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://b.com']),
    );
    final adapter = FakeAdapter();
    // 同一路径先抛连接错误，再返回 200（轮转后重试）
    adapter.enqueueSequence(
      '/x',
      [
        {'success': 0, 'message': 'no stub'},
      ],
      codes: [500],
    );
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
    await dm.applyStartup(
      BackupDomains(apiDomains: ['https://jdforrepam.com', 'https://b.com']),
    );
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
      ..enqueue('/x', {
        'success': 1,
        'data': {'ok': true},
      });
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter;
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    dio.interceptors.add(ic);
    var rotated = false;
    ic.onRotated = () => rotated = true;

    final resp = await dio.get('/x');

    expect(resp.data, {
      'success': 1,
      'data': {'ok': true},
    });
    expect(rotated, isTrue);
    expect(dm.currentUrl, 'https://b.com');
    // 两次请求：第一次走原 baseUrl，重试走新 baseUrl
    expect(adapter.requests, hasLength(2));
    expect(
      adapter.requests.first.uri.toString(),
      startsWith('https://jdforrepam.com'),
    );
    expect(adapter.requests.last.uri.toString(), startsWith('https://b.com'));
  });

  test('连续两次 608 仍可再次轮转（重试标记按请求生效）', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(
        apiDomains: const [
          'https://a.example',
          'https://b.example',
          'https://c.example',
        ],
      ),
    );
    final adapter = FakeAdapter();
    adapter.enqueueSequence(
      '/x',
      [
        {'success': 0, 'action': 'Blocked'},
        {'success': 0, 'action': 'Blocked'},
        {'success': 0, 'action': 'Blocked'},
        {'success': 0, 'action': 'Blocked'},
      ],
      codes: [608, 608, 608, 608],
    );
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter;
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    dio.interceptors.add(ic);
    var rotations = 0;
    ic.onRotated = () => rotations++;

    await expectLater(dio.get('/x'), throwsA(isA<DioException>()));
    expect(dm.currentUrl, 'https://b.example');

    await expectLater(dio.get('/x'), throwsA(isA<DioException>()));
    expect(dm.currentUrl, 'https://c.example');
    expect(rotations, 2);
    expect(adapter.requests.map((request) => request.uri.host).toList(), [
      'a.example',
      'b.example',
      'b.example',
      'c.example',
    ]);
    // 重试标记随请求结束清除，不残留在 RequestOptions.extra。
    for (final request in adapter.requests) {
      expect(
        request.extra.containsKey(DomainSwitchInterceptor.retryMarkerKey),
        isFalse,
      );
    }
  });

  test('并发失败只轮转一次且不会双跳回失效域名', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(
        apiDomains: const ['https://a.example', 'https://b.example'],
      ),
    );
    final adapter = _FailHostAdapter(
      failedHost: 'a.example',
      body: {
        'success': 1,
        'data': {'ok': true},
      },
    );
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter;
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    dio.interceptors.add(ic);
    var rotations = 0;
    ic.onRotated = () => rotations++;

    final responses = await Future.wait([dio.get('/x'), dio.get('/x')]);

    expect(responses, hasLength(2));
    expect(rotations, 1);
    expect(dm.currentUrl, 'https://b.example');
    final hosts = adapter.requests.map((request) => request.host).toList();
    expect(hosts.where((host) => host == 'a.example'), hasLength(2));
    expect(hosts.where((host) => host == 'b.example'), hasLength(2));
  });

  test('轮转重试仍失败时保留重试错误的 response 与类型', () async {
    final prefs = await SharedPreferences.getInstance();
    final dm = await DomainManager.load(prefs);
    await dm.applyStartup(
      BackupDomains(
        apiDomains: const ['https://a.example', 'https://b.example'],
      ),
    );
    final adapter = FakeAdapter();
    adapter.enqueueSequence(
      '/x',
      [
        {'success': 0, 'action': 'Blocked', 'message': '线路被封'},
        {'success': 0, 'action': 'ServerError', 'message': '重试也失败'},
      ],
      codes: [608, 500],
    );
    final dio = Dio(BaseOptions(baseUrl: dm.currentUrl))
      ..httpClientAdapter = adapter;
    final ic = DomainSwitchInterceptor(domainManager: dm, dio: dio);
    dio.interceptors.add(ic);

    DioException? captured;
    try {
      await dio.get('/x');
    } on DioException catch (error) {
      captured = error;
    }

    expect(captured, isNotNull);
    expect(captured!.type, DioExceptionType.badResponse);
    expect(captured.response, isNotNull);
    expect(captured.response!.statusCode, 500);
    expect(captured.response!.data, containsPair('message', '重试也失败'));
  });
}
