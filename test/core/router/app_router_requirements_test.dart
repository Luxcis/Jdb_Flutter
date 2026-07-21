import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _buildApp({required String initialLocation}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(prefs);
  final router = AppRouter.buildForTest(initialLocation: initialLocation);

  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('演员详情路由可渲染', (tester) async {
    await tester.pumpWidget(await _buildApp(initialLocation: '/actor/sample'));
    await tester.pump();

    expect(find.text('演员详情'), findsAtLeastNWidgets(1));
  });

  testWidgets('个人资料路由可渲染', (tester) async {
    await tester.pumpWidget(await _buildApp(initialLocation: '/profile/info'));
    await tester.pump();

    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('电子邮箱'), findsOneWidget);
  });

  testWidgets('我的收藏路由可渲染', (tester) async {
    await tester.pumpWidget(
      await _buildApp(initialLocation: '/profile/favorites'),
    );
    await tester.pump();

    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('收藏的演员'), findsOneWidget);
  });
}
