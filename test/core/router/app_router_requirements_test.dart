import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/features/profile/index.dart';
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

  testWidgets('我的收藏路由可渲染', (tester) async {
    await tester.pumpWidget(
      await _buildApp(initialLocation: '/profile/favorites'),
    );
    await tester.pump();

    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('收藏的演员'), findsOneWidget);
  });

  testWidgets('我想看的路由渲染真实评价影片页且不再使用占位集合页', (tester) async {
    await tester.pumpWidget(
      await _buildApp(initialLocation: '/profile/want-watch'),
    );
    await tester.pump();

    expect(find.byType(ProfileReviewMoviesPage), findsOneWidget);
    expect(find.byType(ProfileMovieCollectionPage), findsNothing);
    expect(find.text('我想看的'), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsNothing);
  });

  testWidgets('近期浏览路由渲染真实近期浏览页', (tester) async {
    await tester.pumpWidget(
      await _buildApp(initialLocation: '/profile/recent'),
    );
    await tester.pump();

    expect(find.byType(ProfileRecentViewedPage), findsOneWidget);
    expect(find.text('近期浏览'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
