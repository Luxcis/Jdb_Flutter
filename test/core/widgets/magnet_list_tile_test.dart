import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/magnet.dart';
import 'package:jade/core/widgets/magnet_list_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('显示详情样式并点击复制补全后的磁链', (tester) async {
    MethodCall? clipboardCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboardCall = call;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MagnetListTile(
            magnet: Magnet(
              hash: 'hash-1',
              title: '桥本香菜.torrent',
              size: '1 MB',
              filesCount: 3,
              publishDate: '2026-08-03',
              isHighDefinition: true,
              hasSubtitle: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('桥本香菜.torrent'), findsOneWidget);
    expect(find.text('3 个文件 / 1 MB'), findsOneWidget);
    expect(find.text('2026-08-03'), findsOneWidget);
    expect(find.text('高清'), findsOneWidget);
    expect(find.text('字幕'), findsOneWidget);
    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);

    await tester.tap(find.byType(MagnetListTile));
    await tester.pump();

    expect(clipboardCall?.arguments, {'text': 'magnet:?xt=urn:btih:hash-1'});
    expect(find.text('磁力链接已复制'), findsOneWidget);
  });

  testWidgets('完整磁链原样复制且共享分隔线保持详情尺寸', (tester) async {
    MethodCall? clipboardCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboardCall = call;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MagnetListTile(
                magnet: Magnet(
                  hash: 'magnet:?xt=urn:btih:complete-hash',
                  title: '完整磁链',
                ),
              ),
              MagnetListDivider(),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(MagnetListTile));
    await tester.pump();

    expect(clipboardCall?.arguments, {
      'text': 'magnet:?xt=urn:btih:complete-hash',
    });
    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.height, 1);
    expect(divider.indent, 16);
    expect(divider.endIndent, 16);
  });
}
