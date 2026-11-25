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
    // 原始异常只进日志，页面展示统一中文文案。
    expect(find.textContaining('加载失败，请重试'), findsOneWidget);
    expect(find.textContaining('bad key'), findsNothing);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.text('重试'), findsOneWidget);
    expect(retries, 0);

    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });

  testWidgets('不可重试错误提示重启或清理数据', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      StartupFailureScreen(
        error: const FormatException('bad key'),
        retryable: false,
        onRetry: () => retries++,
      ),
    );

    expect(find.textContaining('本地数据异常'), findsOneWidget);
    expect(find.textContaining('bad key'), findsNothing);
    expect(find.textContaining('FormatException'), findsNothing);
    // 仍保留重试入口，便于用户自行重试一次。
    expect(find.text('重试'), findsOneWidget);
    expect(retries, 0);
  });
}
