import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/endpoints.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/features/rankings/screens/rankings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('看热播 Tab 首次展示时自动加载影片', (tester) async {
    SharedPreferences.setMockInitialValues({
      'key_baseurl': 'https://jdforrepam.com',
      'key_api_domains': ['https://jdforrepam.com'],
    });
    final prefs = await SharedPreferences.getInstance();
    final auth = await AuthProvider.create(prefs);
    final api = await ApiClient.create(
      prefs: prefs,
      tokenProvider: auth,
      onAuthError: auth.logout,
    );
    final adapter = FakeAdapter();
    api.setAdapterForTest(adapter);
    adapter.enqueue(Endpoints.rankingsPlayback, {
      'success': 1,
      'data': {
        'movies': [
          {
            'id': 'm1',
            'number': 'ABC-001',
            'title': 'Hot Movie',
            'cover_url': 'cover.jpg',
          },
        ],
        'current_page': 1,
        'total_pages': 1,
        'total': 1,
      },
    });

    expect(ApiClient.instanceOrNull, isNotNull);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: RankingsPage()),
      ),
    );

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('高评价'), findsOneWidget);
    expect(
      adapter.requests.map((r) => r.path).toList(),
      contains(Endpoints.rankingsPlayback),
    );
    expect(find.text('Hot Movie'), findsOneWidget);
  });
}
