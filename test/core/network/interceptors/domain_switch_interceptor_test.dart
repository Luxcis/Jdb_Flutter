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
}
