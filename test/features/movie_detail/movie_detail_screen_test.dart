import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/features/movie_detail/screens/movie_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

Future<FakeAdapter> _setupApiClient() async {
  final adapter = FakeAdapter();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(StorageKeys.baseUrl, 'https://jdforrepam.com');
  await prefs.setStringList(StorageKeys.apiDomains, ['https://jdforrepam.com']);
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: _TokenProvider(),
    onAuthError: () {},
  );
  api.setAdapterForTest(adapter);
  return adapter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MovieDetailPage 主详情成功时附属接口失败不影响渲染', (tester) async {
    final adapter = await _setupApiClient();
    adapter.enqueue('/api/v4/movies/m1', {
      'success': 1,
      'data': {
        'movie': {
          'id': 'm1',
          'number': 'SSIS-001',
          'title': '测试影片',
          'cover_url': 'covers/test.jpg',
          'actors': [],
          'tags': [
            {'name': '剧情'},
          ],
        },
      },
    });

    await tester.pumpWidget(const MaterialApp(home: MovieDetailPage(id: 'm1')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('测试影片'), findsOneWidget);
    expect(find.text('番号: SSIS-001'), findsOneWidget);
    expect(find.text('剧情'), findsOneWidget);
  });
}
