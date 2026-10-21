import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/widgets/online_play_source_sheet.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required String number,
    required Future<void> Function(Uri? url) onShow,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  // show 在抽屉 pop 后返回点选源的链接。
                  final url = await OnlinePlaySourceSheet.show(
                    context,
                    number: number,
                  );
                  await onShow(url);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('抽屉按注册表顺序列出三个播放源', (tester) async {
    final shown = <Uri?>[];
    await pumpSheet(
      tester,
      number: 'IPX-538',
      onShow: (url) async => shown.add(url),
    );

    expect(find.text('Jable'), findsOneWidget);
    expect(find.text('SupJav'), findsOneWidget);
    expect(find.text('MissAV'), findsOneWidget);
    expect(find.text('jable.tv'), findsOneWidget);
    expect(find.text('supjav.com'), findsOneWidget);
    expect(find.text('missav.live'), findsOneWidget);
    expect(find.text('选择在线播放源'), findsOneWidget);
    expect(shown, isEmpty);
  });

  testWidgets('点选 MissAV 关闭抽屉并传出构造链接', (tester) async {
    final shown = <Uri?>[];
    await pumpSheet(
      tester,
      number: 'IPX-538',
      onShow: (url) async => shown.add(url),
    );

    await tester.tap(find.byKey(const Key('online-play-source-missav')));
    await tester.pumpAndSettle();

    expect(shown, [Uri.parse('https://missav.live/ipx-538')]);
  });

  testWidgets('点选 Jable 传出 videos 路径链接', (tester) async {
    final shown = <Uri?>[];
    await pumpSheet(
      tester,
      number: 'IPX-538',
      onShow: (url) async => shown.add(url),
    );

    await tester.tap(find.byKey(const Key('online-play-source-jable')));
    await tester.pumpAndSettle();

    expect(shown, [Uri.parse('https://jable.tv/videos/ipx-538')]);
  });

  testWidgets('点击遮罩关闭抽屉不传出链接', (tester) async {
    final shown = <Uri?>[];
    await pumpSheet(
      tester,
      number: 'IPX-538',
      onShow: (url) async => shown.add(url),
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(shown, [null]);
  });
}
