import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/main.dart' as app_main;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingStartupApi implements StartupApi {
  final Completer<StartupData> completer = Completer<StartupData>();

  @override
  Future<StartupData> fetchStartup() => completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App 启动先显示加载页且不提前渲染首页', (tester) async {
    final startupApi = _PendingStartupApi();

    await app_main.mainForTest(startupApi: startupApi);
    await tester.pump();
    await tester.pump();

    expect(find.byType(app_main.MyApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('首页'), findsNothing);
  });

  testWidgets('启动请求期间应用重建，请求成功后仍进入首页', (tester) async {
    final startupApi = _PendingStartupApi();

    await app_main.mainForTest(
      startupApi: startupApi,
      decoder: (_) =>
          const BackupDomains(apiDomains: ['https://backup.example']),
    );
    await tester.pump();
    await tester.pump();

    final appContext = tester.element(find.byType(app_main.MyApp));
    appContext.read<ThemeProvider>().setThemeMode(ThemeMode.dark);
    await tester.pump();

    startupApi.completer.complete(
      const StartupData(backupDomainsData: 'ciphertext'),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('首页'), findsAtLeastNWidgets(1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
