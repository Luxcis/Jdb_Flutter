import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/cached_image.dart';

void main() {
  testWidgets('相对路径自动拼接 CDN 前缀', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedImage('covers/test.jpg'),
      ),
    );
    await tester.pump();
    expect(find.byType(CachedImage), findsOneWidget);
  });

  testWidgets('http 开头的 URL 不拼接 CDN', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedImage('https://other.cdn/covers/test.jpg'),
      ),
    );
    await tester.pump();
    expect(find.byType(CachedImage), findsOneWidget);
  });

  testWidgets('支持 width/height 参数', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CachedImage('covers/test.jpg', width: 100, height: 100),
      ),
    );
    await tester.pump();
    expect(find.byType(CachedImage), findsOneWidget);
  });
}
