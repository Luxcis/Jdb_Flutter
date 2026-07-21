import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/api_exception.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<String> _getDeviceUuid() async {
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

  void _login() async {
    final api = ApiClient.instanceOrNull;
    if (api == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await api.post(Endpoints.sessions, data: {
        'username': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'device_uuid': await _getDeviceUuid(),
        'device_name': 'Jade',
        'device_model': 'Flutter',
        'platform': 'android',
        'system_version': '14',
        'app_channel': 'google',
        'app_version': '1.9.29',
        'app_version_number': '35',
      });
      final data = resp.data;
      final token = data['token'] as String;
      final user = data['user'] as Map<String, dynamic>;
      if (!mounted) return;
      await context.read<AuthProvider>().login(token: token, user: user);
      if (!mounted) return;
      final from = GoRouterState.of(context).uri.queryParameters['from'] ?? '';
      context.go(from.isNotEmpty ? from : '/home');
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

    return Scaffold(
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
    );
  }
}
