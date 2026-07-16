import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/main.dart';

Future<Widget> _buildApp() async {
  SharedPreferences.setMockInitialValues({});
  final themeProvider = await ThemeProvider.create();
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: themeProvider)],
    child: const MyApp(),
  );
}

void main() {
  testWidgets('App renders home page with title', (WidgetTester tester) async {
    await tester.pumpWidget(await _buildApp());

    expect(find.text('Template'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('Can navigate to settings page', (WidgetTester tester) async {
    await tester.pumpWidget(await _buildApp());

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('应用主题'), findsOneWidget);
  });
}
