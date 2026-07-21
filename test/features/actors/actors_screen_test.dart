import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/actors/screens/actors_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('演员页展示设计需求中的六个 Tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: ActorsPage()),
      ),
    );

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('有码(女)'), findsOneWidget);
    expect(find.text('有码(男)'), findsOneWidget);
    expect(find.text('无码'), findsOneWidget);
    expect(find.text('欧美(女)'), findsOneWidget);
    expect(find.text('欧美(男)'), findsOneWidget);
  });
}
