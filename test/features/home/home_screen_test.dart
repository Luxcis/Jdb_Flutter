import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/home/screens/home_screen.dart';

void main() {
  testWidgets('首页内容使用 SafeArea 避免状态栏遮挡', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.byType(SafeArea), findsOneWidget);
  });
}
