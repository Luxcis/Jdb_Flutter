// test/features/profile/token_authentication_following_tags_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/follow_tag.dart';
import 'package:jade/core/network/cache_service.dart';
import 'package:jade/core/network/domain_manager.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/providers/following_tags_provider.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/services/following_tags_service.dart';
import 'package:jade/core/services/following_tags_store.dart';
import 'package:jade/core/services/token_authentication_service.dart';
import 'package:jade/core/storage/testing/in_memory_secure_store.dart';
import 'package:jade/features/profile/screens/profile_settings_screen.dart';
import 'package:jade/features/profile/services/app_version_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCacheService implements CacheService {
  @override
  Future<int> getCacheSizeBytes() async => 0;

  @override
  Future<void> clearAll() async {}
}

final class _FixedAppVersionService implements AppVersionService {
  const _FixedAppVersionService(this.version);

  final String version;

  @override
  Future<String> loadVersion() async => version;
}

final class _FakeTokenAuthenticationService
    implements TokenAuthenticationService {
  _FakeTokenAuthenticationService(this.user);

  final Map<String, dynamic> user;
  var calls = 0;
  String? lastToken;

  @override
  Future<Map<String, dynamic>> authenticate(String token) async {
    calls++;
    lastToken = token;
    return user;
  }
}

class _MemoryFollowingStore implements FollowingTagsStore {
  List<FollowTagItem> stored = [];

  @override
  Future<void> clear() async => stored = [];

  @override
  Future<List<FollowTagItem>> load() async => stored;

  @override
  Future<void> save(List<FollowTagItem> tags) async => stored = List.of(tags);
}

class _RecordingFollowingSource implements FollowingTagsDataSource {
  final pushed = <List<FollowTagItem>>[];

  @override
  Future<FollowTagItem> follow({
    required String name,
    required String value,
  }) async => FollowTagItem(id: 'new', name: name, value: value);

  @override
  Future<void> unfollow(String id) async {}

  @override
  Future<List<FollowTagItem>> batchPush(List<FollowTagItem> tags) async {
    pushed.add(List.of(tags));
    return tags;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('认证 Token 换号后清空关注标签缓存，冷启动不再推送旧账号标签', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsProvider.create(prefs);
    final theme = await ThemeProvider.create();
    final domainManager = await DomainManager.load(prefs);
    final auth = await AuthProvider.create(
      prefs,
      secure: InMemorySecureValueStore(),
    );
    await auth.login(
      token: 'old-token',
      user: {'id': 1, 'username': 'old-user'},
    );

    final store = _MemoryFollowingStore()
      ..stored = [
        const FollowTagItem(id: 'old-tag', name: '旧账号标签', value: '0:a:old'),
      ];
    final source = _RecordingFollowingSource();
    final following = FollowingTagsProvider(store: store, dataSource: source);
    await following.initialize();
    expect(following.tags, hasLength(1));

    final tokenService = _FakeTokenAuthenticationService({
      'id': 2,
      'username': 'new-user',
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: domainManager),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: following),
        ],
        child: MaterialApp(
          home: ProfileSettingsScreen(
            cacheService: _FakeCacheService(),
            appVersionService: const _FixedAppVersionService('0.7.1'),
            tokenAuthenticationService: tokenService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('当前版本'));
    }
    await tester.pumpAndSettle();
    expect(find.text('认证 Token'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'new-token');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(tokenService.calls, 1);
    expect(auth.token, 'new-token');
    expect(auth.user?['username'], 'new-user');
    expect(following.tags, isEmpty);
    expect(store.stored, isEmpty);

    // 模拟冷启动：新 provider 从同一存储加载，并执行 startup 的 batch_push。
    final restartedSource = _RecordingFollowingSource();
    final restarted = FollowingTagsProvider(
      store: store,
      dataSource: restartedSource,
    );
    await restarted.initialize();
    expect(restarted.tags, isEmpty);
    await restarted.syncFromRemote();
    expect(restartedSource.pushed.single, isEmpty);
  });
}
