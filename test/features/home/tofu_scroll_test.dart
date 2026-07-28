import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/features/home/widgets/tofu_scroll.dart';

void main() {
  testWidgets('首页入口使用横向圆角卡片并保留路由', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TofuScroll()),
        GoRoute(
          path: '/rankings',
          builder: (_, _) => const Scaffold(body: Text('排行榜')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byType(Card), findsNWidgets(TofuScroll.items.length));
    expect(find.byType(InkWell), findsNWidgets(TofuScroll.items.length));
    final firstCard = tester.widget<Card>(find.byType(Card).first);
    expect(firstCard.shape, isA<RoundedRectangleBorder>());

    await tester.tap(find.text('看热播'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/rankings');
  });
}
