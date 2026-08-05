import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/app.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/backup_domains_decryptor.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/features/search/services/search_history_store.dart';

export 'package:jade/app.dart' show MyApp;

Future<void> mainForTest({
  StartupApi? startupApi,
  StartupDomainsDecoder? decoder,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await _buildEntry(startupApi: startupApi, decoder: decoder));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await _buildEntry());
}

Future<Widget> _buildEntry({
  StartupApi? startupApi,
  StartupDomainsDecoder? decoder,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final themeProvider = await ThemeProvider.create();
  final authProvider = await AuthProvider.create(prefs);
  final settingsProvider = await SettingsProvider.create(prefs);
  final apiClient = await ApiClient.create(
    prefs: prefs,
    tokenProvider: authProvider,
    onAuthError: () {
      unawaited(authProvider.logout());
      AppRouter.goLoginForAuthError();
    },
  );
  final startupProvider = StartupProvider.create(
    startupApi: startupApi ?? StartupApiClient.create(),
    apiClient: apiClient,
    domainManager: apiClient.domainManager,
    decoder: decoder ?? BackupDomainsDecryptor.decrypt,
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: themeProvider),
      ChangeNotifierProvider.value(value: authProvider),
      ChangeNotifierProvider.value(value: settingsProvider),
      ChangeNotifierProvider.value(value: startupProvider),
      ChangeNotifierProvider.value(value: apiClient.domainManager),
      ChangeNotifierProvider(create: (_) => SearchHistoryStore(prefs)),
    ],
    child: const MyApp(),
  );
}
