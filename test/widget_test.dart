import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/main.dart';

void main() {
  testWidgets('App renders home page with tab navigation',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => mainForTest());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('首页'), findsAtLeastNWidgets(1));
    expect(find.text('排行榜'), findsOneWidget);
    expect(find.text('类别'), findsOneWidget);
    expect(find.text('演员'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
