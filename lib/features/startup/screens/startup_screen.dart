import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/router/routes.dart';
import 'package:provider/provider.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

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
    if (succeeded && mounted) {
      context.go(AppRoutes.home);
    }
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
