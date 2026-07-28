import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/features/home/widgets/tofu_scroll.dart';

void main() {
  testWidgets('首页入口使用横向圆角卡片并保留路由', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Align(alignment: Alignment.topCenter, child: TofuScroll()),
          ),
        ),
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
    final hotCard = find.byKey(const Key('tofu-看热播'));
    final articleCard = find.byKey(const Key('tofu-AV资讯'));
    expect(tester.getSize(hotCard), const Size.square(72));
    expect(tester.getSize(articleCard), const Size.square(72));
    expect(
      tester.getTopLeft(articleCard).dx - tester.getTopRight(hotCard).dx,
      8,
    );

    final card = tester.widget<Card>(hotCard);
    expect(card.margin, EdgeInsets.zero);
    expect(card.shape, isA<RoundedRectangleBorder>());

    await tester.tap(find.text('看热播'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/rankings');
    expect(router.state.uri.queryParameters['tab'], 'hot');
  });
}
