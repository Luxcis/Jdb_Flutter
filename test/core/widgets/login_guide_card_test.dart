import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/login_guide_card.dart';

void main() {
  testWidgets('LoginGuideCard 渲染提示信息和去登录按钮', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginGuideCard(
          message: '请登录查看',
          loginPath: '/rankings',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('请登录查看'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
  });

  testWidgets('LoginGuideCard 渲染锁图标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginGuideCard(message: '请登录'),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
