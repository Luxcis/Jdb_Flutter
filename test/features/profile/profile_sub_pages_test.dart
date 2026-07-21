import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/profile/screens/profile_sub_pages.dart';

void main() {
  testWidgets('个人资料页展示资料与账号操作 cell', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileInfoPage()));

    expect(find.text('电子邮箱'), findsOneWidget);
    expect(find.text('短评被举报次数'), findsOneWidget);
    expect(find.text('短评被删次数'), findsOneWidget);
    expect(find.text('禁言次数'), findsOneWidget);
    expect(find.text('待审核/已通过订正数'), findsOneWidget);
    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('修改用户名'), findsOneWidget);
  });

  testWidgets('我的收藏页展示六类收藏入口', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileFavoritesPage()));

    expect(find.text('收藏的演员'), findsOneWidget);
    expect(find.text('收藏的片商'), findsOneWidget);
    expect(find.text('收藏的系列'), findsOneWidget);
    expect(find.text('收藏的导演'), findsOneWidget);
    expect(find.text('收藏的番号'), findsOneWidget);
    expect(find.text('清单'), findsOneWidget);
  });

  testWidgets('设置页展示外观、线路、默认筛选和清缓存', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileSettingsPage()));

    expect(find.text('外观模式'), findsOneWidget);
    expect(find.text('线路选择'), findsOneWidget);
    expect(find.text('默认筛选标签'), findsOneWidget);
    expect(find.text('清除缓存'), findsOneWidget);
  });
}
