import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/app.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/startup_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';

export 'package:jade/app.dart' show MyApp;

Future<void> mainForTest() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await _buildEntry());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await _buildEntry());
}

Future<Widget> _buildEntry() async {
  final prefs = await SharedPreferences.getInstance();
  final themeProvider = await ThemeProvider.create();
  final authProvider = await AuthProvider.create(prefs);
  final settingsProvider = await SettingsProvider.create(prefs);
  final apiClient = await ApiClient.create(
    prefs: prefs,
    tokenProvider: authProvider,
    onAuthError: authProvider.logout,
  );
  final startupProvider = StartupProvider.create(
    apiClient,
    apiClient.domainManager,
  );
  // fire-and-forget 域名刷新
  startupProvider.fetchStartup();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: themeProvider),
      ChangeNotifierProvider.value(value: authProvider),
      ChangeNotifierProvider.value(value: settingsProvider),
      ChangeNotifierProvider.value(value: startupProvider),
    ],
    child: const MyApp(),
  );
}
