import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/services/session_refresh_service.dart';
import 'package:jade/features/following/services/following_tags_provider.dart';
import 'package:jade/features/profile/services/token_authentication_service.dart';
import 'package:provider/provider.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key, this.sessionRefreshService});

  final SessionRefreshService? sessionRefreshService;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load({bool retry = false}) async {
    final provider = context.read<StartupProvider>();
    final succeeded = retry ? await provider.retry() : await provider.load();
    if (!succeeded || !mounted) return;
    await _refreshSessionThenNavigate();
  }

  Future<void> _refreshSessionThenNavigate() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLogged) {
      context.go(AppRoutes.home);
      return;
    }
    final service =
        widget.sessionRefreshService ??
        ApiSessionRefreshService(
          auth: auth,
          tokenAuthentication: ApiTokenAuthenticationService(
            ApiClient.instance,
          ),
        );
    final status = await service.refresh();
    if (!mounted) return;
    if (status == SessionRefreshStatus.expired) {
      await context.read<FollowingTagsProvider>().clear();
      if (!mounted) return;
      context.go(
        Uri(
          path: AppRoutes.login,
          queryParameters: {'from': AppRoutes.home, 'reason': 'expired'},
        ).toString(),
      );
      return;
    }
    if (status == SessionRefreshStatus.success) {
      await context.read<FollowingTagsProvider>().syncFromRemote();
      if (!mounted) return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final startup = context.watch<StartupProvider>();
    final failed = startup.status == StartupStatus.failure;
    return Scaffold(
      body: Center(
        child: failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  Text(
                    startup.errorMessage ?? StartupProvider.failureMessage,
                    textAlign: TextAlign.center,
                  ),
                  FilledButton(
                    onPressed: () => _load(retry: true),
                    child: const Text('重试'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
