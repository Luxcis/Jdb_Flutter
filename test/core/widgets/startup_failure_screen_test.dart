import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/startup_failure_screen.dart';

void main() {
  testWidgets('展示初始化失败原因并可触发重试', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      StartupFailureScreen(
        error: const FormatException('bad key'),
        onRetry: () => retries++,
      ),
    );

    expect(find.textContaining('启动初始化失败'), findsOneWidget);
    expect(find.textContaining('bad key'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(retries, 0);

    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });
}
