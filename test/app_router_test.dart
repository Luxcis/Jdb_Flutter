import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/router/app_router.dart';

void main() {
  testWidgets('AppRouter 默认渲染首页占位', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: AppRouter.buildForTest(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsAtLeastNWidgets(1));
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('点击排行榜 Tab 切换', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: AppRouter.buildForTest(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('排行榜'));
    await tester.pumpAndSettle();
    expect(find.text('排行榜占位'), findsOneWidget);
  });
}
