import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/device/login_device_info_service.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/login_credential_store.dart';
import 'package:jade/features/following/models/follow_tag.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.deviceParametersProvider,
    this.credentialStore,
  });

  final LoginDeviceParametersProvider? deviceParametersProvider;
  final LoginCredentialStore? credentialStore;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  late final LoginCredentialStore _credentialStore;
  var _usernameEdited = false;
  var _passwordEdited = false;
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _credentialStore =
        widget.credentialStore ?? SecureLoginCredentialStore.createDefault();
    _restoreCredentials();
  }

  Future<void> _restoreCredentials() async {
    try {
      final credentials = await _credentialStore.read();
      if (!mounted) return;

      final username = credentials.username;
      if (!_usernameEdited && username != null && username.isNotEmpty) {
        _emailCtrl.text = username;
      }

      final password = credentials.password;
      if (!_passwordEdited && password != null && password.isNotEmpty) {
        _passCtrl.text = password;
      }
    } catch (_) {
      // 安全存储异常不应阻止用户手动登录。
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final username = _emailCtrl.text.trim();
      final password = _passCtrl.text;
      final deviceProvider =
          widget.deviceParametersProvider ??
          await LoginDeviceInfoService.createDefault();
      final deviceParameters = await deviceProvider.load();
      final resp = await api.post(
        Endpoints.sessions,
        data: FormData.fromMap({
          'username': username,
          'password': password,
          ...deviceParameters.toMap(),
        }),
      );
      final data = resp.data;
      final token = data['token'] as String;
      final user = data['user'] as Map<String, dynamic>;
      try {
        await _credentialStore.save(username: username, password: password);
      } catch (_) {
        // 缓存失败不回滚已成功的登录。
      }
      if (!mounted) return;
      await context.read<AuthProvider>().login(token: token, user: user);
      if (!mounted) return;
      try {
        final following = data['following_tags'];
        if (following is List) {
          final tags = following
              .map((e) =>
                  FollowTagItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(growable: false);
          await context.read<FollowingTagsProvider>().syncFromLogin(tags);
        }
      } catch (_) {
        // following_tags 解析失败视为空列表，不影响已成功的登录。
      }
      if (!mounted) return;
      final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
      context.go(from.isNotEmpty ? Uri.decodeComponent(from) : '/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? '登录失败';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
    final hasFrom = from.isNotEmpty;
    final reason = GoRouterState.of(context).uri.queryParameters['reason'];
    final sessionExpired = reason == 'expired';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(hasFrom ? from : '/home');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('登录')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasFrom)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '请登录后继续',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              if (sessionExpired)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '登录已过期，请重新登录',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextField(
                controller: _emailCtrl,
                onChanged: (_) => _usernameEdited = true,
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
                onChanged: (_) => _passwordEdited = true,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  final to = hasFrom ? '/register?from=$from' : '/register';
                  context.push(to);
                },
                child: const Text('没有账号？立即注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
