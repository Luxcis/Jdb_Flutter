import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/confirm_dialog.dart';

void main() {
  Future<bool> showDialogAndAct(WidgetTester tester, String label) async {
    bool result = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await ConfirmDialog.show(
                  context,
                  title: '测试标题',
                  content: '确定删除「foo」吗？',
                  confirmLabel: '清空',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('确认按钮返回 true 且保留文案', (tester) async {
    final result = await showDialogAndAct(tester, '清空');
    expect(result, isTrue);
  });

  testWidgets('取消按钮返回 false', (tester) async {
    final result = await showDialogAndAct(tester, '取消');
    expect(result, isFalse);
  });
}
