import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/startup_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/main.dart';

class _SuccessfulStartupApi implements StartupApi {
  @override
  Future<StartupData> fetchStartup() async {
    return const StartupData(backupDomainsData: 'ciphertext');
  }
}

void main() {
  testWidgets(
    'App renders home page with tab navigation',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await mainForTest(
        startupApi: _SuccessfulStartupApi(),
        decoder: (_) =>
            const BackupDomains(apiDomains: ['https://backup.example']),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('首页'), findsAtLeastNWidgets(1));
      expect(find.text('排行榜'), findsOneWidget);
      expect(find.text('类别'), findsOneWidget);
      expect(find.text('演员'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
