import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/utils/user_facing_error.dart';
import 'package:jade/features/auth/services/auth_session_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<String> _deviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    var uuid = prefs.getString(StorageKeys.deviceUuid);
    if (uuid == null || uuid.isEmpty) {
      uuid =
          '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
          '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      await prefs.setString(StorageKeys.deviceUuid, uuid);
    }
    return uuid;
  }

  void _register() async {
    if (_loading) return;
    final service = AuthSessionService.resolve();
    if (service == null) return;

    final email = _emailCtrl.text.trim();
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = '两次密码不一致');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = '密码至少6位');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deviceUuid = await _deviceUuid();
      await service.register(
        email: email,
        password: _passCtrl.text,
        deviceUuid: deviceUuid,
      );
      if (!mounted) return;
      final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
      final to = from.isNotEmpty ? '/login?from=$from' : '/login';
      context.go(to);
    } catch (error, stackTrace) {
      debugPrint('Register failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = _registerErrorMessage(error);
        _loading = false;
      });
    }
  }

  /// 注册失败文案：优先服务端中文 message，网络类复用统一文案。
  String _registerErrorMessage(Object error) {
    final apiError = userFacingApiException(error);
    if (apiError != null) {
      final message = apiError.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      return '注册失败，请重试';
    }
    if (error is DioException) {
      final message = userFacingErrorMessage(error);
      if (message == '网络连接失败，请检查网络') return message;
    }
    return '注册失败，请重试';
  }

  @override
  Widget build(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
    final hasFrom = from.isNotEmpty;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(hasFrom ? from : '/login');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('注册')),
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight > 48
                    ? constraints.maxHeight - 48
                    : 0,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasFrom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '注册后可继续操作',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                      decoration: const InputDecoration(
                        labelText: '确认密码',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('注册'),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        final to = hasFrom ? '/login?from=$from' : '/login';
                        context.push(to);
                      },
                      child: const Text('已有账号？去登录'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
