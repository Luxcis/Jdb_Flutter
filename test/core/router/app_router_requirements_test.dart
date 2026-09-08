import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/features/profile/index.dart';
import 'package:jade/features/search/models/magnet_search_sort.dart';
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

  testWidgets('搜索结果页修改关键词提交后重建为影片 Tab 的新结果页', (tester) async {
    await tester.pumpWidget(
      await _buildApp(
        initialLocation: '${AppRoutes.searchResults}?q=旧关键词',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('番号'));
    await tester.pumpAndSettle();
    expect(find.text('暂无番号'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '新关键词');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '新关键词',
    );
  });

  testWidgets('磁链结果页修改关键词提交后重建并重置排序', (tester) async {
    await tester.pumpWidget(
      await _buildApp(
        initialLocation:
            '${AppRoutes.magnetSearchResults}?q=旧关键词&from_recent=true',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('未找到相关磁链'), findsOneWidget);

    await tester.tap(find.text('时间'));
    await tester.pumpAndSettle();
    expect(_magnetSortSelection(tester), MagnetSearchSort.created);

    await tester.enterText(find.byType(TextField), '新关键词');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(_magnetSortSelection(tester), MagnetSearchSort.relevance);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '新关键词',
    );
  });
}

MagnetSearchSort _magnetSortSelection(WidgetTester tester) => tester
    .widget<SegmentedButton<MagnetSearchSort>>(
      find.byType(SegmentedButton<MagnetSearchSort>),
    )
    .selected
    .single;
