import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/router/routes.dart';
import 'package:jade/core/widgets/search_entry.dart';

GoRouter _router(Widget source) => GoRouter(
  initialLocation: '/source',
  routes: [
    GoRoute(path: '/source', builder: (_, _) => source),
    GoRoute(
      path: AppRoutes.search,
      builder: (_, _) => const Scaffold(body: Text('搜索页')),
    ),
  ],
);

void main() {
  testWidgets('首页搜索栏显示图标和文案并进入搜索路由', (tester) async {
    final router = _router(const Scaffold(body: Align(child: HomeSearchBar())));
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('输入演员或番号等关键字'), findsOneWidget);

    await tester.tap(find.byType(HomeSearchBar));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.search);
  });

  testWidgets('顶部搜索按钮显示提示并进入搜索路由', (tester) async {
    final router = _router(
      Scaffold(appBar: AppBar(actions: const [SearchIconButton()])),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byTooltip('搜索'), findsOneWidget);

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.search);
  });
}
