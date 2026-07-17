import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/main.dart' as app_main;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('App 启动渲染底导与首页', (tester) async {
    await app_main.mainForTest();
    await tester.pumpAndSettle();
    expect(find.byType(app_main.MyApp), findsOneWidget);
    expect(find.text('首页'), findsAtLeastNWidgets(1));
  });
}
