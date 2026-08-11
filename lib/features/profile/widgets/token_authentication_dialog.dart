import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jade/core/network/api_exception.dart';

typedef AuthenticateToken = Future<Map<String, dynamic>> Function(String token);

typedef SaveAuthenticatedSession =
    Future<void> Function({
      required String token,
      required Map<String, dynamic> user,
    });

class TokenAuthenticationDialog extends StatefulWidget {
  const TokenAuthenticationDialog({
    super.key,
    required this.authenticate,
    required this.saveSession,
  });

  final AuthenticateToken authenticate;
  final SaveAuthenticatedSession saveSession;

  @override
  State<TokenAuthenticationDialog> createState() =>
      _TokenAuthenticationDialogState();
}

class _TokenAuthenticationDialogState extends State<TokenAuthenticationDialog> {
  static const _redactedSecret = '[REDACTED_SECRET]';

  final _controller = TextEditingController();
  var _loading = false;
  String? _error;

  Future<void> _submit() async {
    final token = _controller.text.trim();
    if (token.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    late final Map<String, dynamic> user;
    try {
      user = await widget.authenticate(token);
    } on ApiException catch (error) {
      _showError(error.message ?? 'Token 验证失败，请重试', secret: token);
      return;
    } on DioException catch (error) {
      final cause = error.error;
      final message = cause is ApiException ? cause.message : null;
      _showError(
        message != null && message.trim().isNotEmpty
            ? message
            : 'Token 验证失败，请重试',
        secret: token,
      );
      return;
    } catch (_) {
      _showError('Token 验证失败，请重试', secret: token);
      return;
    }

    try {
      await widget.saveSession(token: token, user: user);
    } catch (_) {
      _showError('保存失败，请重试', secret: token);
      return;
    }

    if (mounted) Navigator.pop(context, true);
  }

  void _showError(String message, {required String secret}) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message.replaceAll(secret, _redactedSecret);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_loading,
      child: AlertDialog(
        title: const Text('认证 Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('输入新的认证 Token 将覆盖当前登录信息。'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_loading,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Token',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('确定'),
          ),
        ],
      ),
    );
  }
}
