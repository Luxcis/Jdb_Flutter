import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/login_credential_store.dart';
import 'package:jade/core/models/follow_tag.dart';
import 'package:jade/core/providers/following_tags_provider.dart';
import 'package:jade/core/services/following_tags_service.dart';
import 'package:jade/core/services/following_tags_store.dart';
import 'package:jade/features/profile/screens/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/testing/in_memory_secure_store.dart';

/// 写入抛异常的 SecureValueStore，用于验证登出持久化失败路径。
class _FailingWriteSecureStore extends InMemorySecureValueStore {
  _FailingWriteSecureStore({this.successWrites = 0});

  var _writes = 0;
  final int successWrites;

  @override
  Future<void> write(String key, String value) async {
    final index = _writes++;
    if (index >= successWrites) {
      throw StateError('secure write failed');
    }
    await super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('主动退出清除密码但保留用户名', (tester) async {
    final store = _MemoryLoginCredentialStore(
      credentials: const SavedLoginCredentials(
        username: 'cached-user',
        password: 'cached-password',
      ),
    );
    final subject = await _pumpProfile(tester, credentialStore: store);

    await tester.scrollUntilVisible(
      find.text('退出登录'),
      200,
      scrollable: find.byType(Scrollable),
    );
    // 删除"个人资料"cell 后，ensureVisible 的滚动量可能不足以让
    // 列表尾部完全进入视口，这里补一次显式滚动确保可点击。
    await tester.drag(find.byType(Scrollable), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(store.clearPasswordCalls, 1);
    expect(store.credentials.username, 'cached-user');
    expect(store.credentials.password, isNull);
    expect(subject.auth.isLogged, isFalse);
    expect(subject.router.state.uri.path, '/home');
  });

  testWidgets('清除密码失败时仍完成主动退出', (tester) async {
    final store = _MemoryLoginCredentialStore(
      credentials: const SavedLoginCredentials(
        username: 'cached-user',
        password: 'cached-password',
      ),
      clearPasswordError: StateError('secure delete failed'),
    );
    final subject = await _pumpProfile(tester, credentialStore: store);

    await tester.scrollUntilVisible(
      find.text('退出登录'),
      200,
      scrollable: find.byType(Scrollable),
    );
    // 同上：补一次显式滚动确保列表尾部完全进入视口。
    await tester.drag(find.byType(Scrollable), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(store.clearPasswordCalls, 1);
    expect(subject.auth.isLogged, isFalse);
    expect(subject.router.state.uri.path, '/home');
  });

  testWidgets('登出持久化失败时仍清空会话、清关注缓存并回首页', (tester) async {
    final store = _MemoryLoginCredentialStore(
      credentials: const SavedLoginCredentials(
        username: 'cached-user',
        password: 'cached-password',
      ),
    );
    final followingStore = _MemoryFollowingStore()
      ..stored = [
        const FollowTagItem(id: 'tag-1', name: '旧账号标签', value: '0:a:old'),
      ];
    final subject = await _pumpProfile(
      tester,
      credentialStore: store,
      // login 首次写入成功，logout 的 tombstone 写入失败。
      secure: _FailingWriteSecureStore(successWrites: 1),
      followingStore: followingStore,
    );
    expect(subject.following.tags, hasLength(1));

    await tester.scrollUntilVisible(
      find.text('退出登录'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.drag(find.byType(Scrollable), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(subject.auth.isLogged, isFalse);
    expect(subject.auth.token, isNull);
    expect(subject.following.tags, isEmpty);
    expect(subject.followingStore.stored, isEmpty);
    expect(store.clearPasswordCalls, 1);
    expect(subject.router.state.uri.path, '/home');
  });
}

Future<
  ({
    AuthProvider auth,
    GoRouter router,
    FollowingTagsProvider following,
    _MemoryFollowingStore followingStore,
  })
>
_pumpProfile(
  WidgetTester tester, {
  required LoginCredentialStore credentialStore,
  SecureValueStore? secure,
  _MemoryFollowingStore? followingStore,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = await AuthProvider.create(
    prefs,
    secure: secure ?? InMemorySecureValueStore(),
  );
  await auth.login(
    token: 'test-token',
    user: {'id': 1, 'username': 'test-user'},
  );

  final store = followingStore ?? _MemoryFollowingStore();
  final following = FollowingTagsProvider(
    store: store,
    dataSource: const UnavailableFollowingTagsDataSource(),
  );
  await following.initialize();

  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            ProfileScreen(credentialStore: credentialStore),
      ),
      GoRoute(path: '/home', builder: (context, state) => const SizedBox()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider.value(value: following),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return (
    auth: auth,
    router: router,
    following: following,
    followingStore: store,
  );
}

final class _MemoryFollowingStore implements FollowingTagsStore {
  List<FollowTagItem> stored = [];
  @override
  Future<void> clear() async => stored = [];
  @override
  Future<List<FollowTagItem>> load() async => stored;
  @override
  Future<void> save(List<FollowTagItem> tags) async => stored = List.of(tags);
}

final class _MemoryLoginCredentialStore implements LoginCredentialStore {
  _MemoryLoginCredentialStore({
    required this.credentials,
    this.clearPasswordError,
  });

  SavedLoginCredentials credentials;
  final Object? clearPasswordError;
  var clearPasswordCalls = 0;

  @override
  Future<SavedLoginCredentials> read() async => credentials;

  @override
  Future<void> save({
    required String username,
    required String password,
  }) async {
    credentials = SavedLoginCredentials(username: username, password: password);
  }

  @override
  Future<void> clearPassword() async {
    clearPasswordCalls++;
    if (clearPasswordError case final error?) throw error;
    credentials = SavedLoginCredentials(username: credentials.username);
  }
}
