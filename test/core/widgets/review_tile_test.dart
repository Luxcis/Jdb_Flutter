import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderParagraph;
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/network/testing/fake_adapter.dart';
import 'package:jade/core/providers/auth_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:jade/core/widgets/review_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/storage/testing/in_memory_secure_store.dart';

Review _review({
  ReviewMovie? movie,
  String content = '评论内容',
  bool liked = false,
}) =>
    Review(
      id: 'r1',
      author: const ReviewAuthor(name: '作者A'),
      watchedCount: 3,
      score: 4.5,
      content: content,
      likedCount: 17,
      liked: liked,
      createdAt: '2016-09-24',
      movie: movie,
    );

const _movie = ReviewMovie(
  id: 'm1',
  number: 'ABC-001',
  title: '这是一个非常长的影片标题需要省略显示最多两行',
  releaseDate: '2026-08-05',
  thumbUrl: 'cover.jpg',
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _wrapWithAuth(Widget child, AuthProvider auth) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(home: Scaffold(body: child)),
    );

Future<AuthProvider> _loggedOutAuth() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AuthProvider.create(prefs, secure: InMemorySecureValueStore());
}

Future<AuthProvider> _loggedInAuth() async {
  final auth = await _loggedOutAuth();
  await auth.login(token: 't', user: {'id': 1, 'username': 'u'});
  return auth;
}

class _TestTokenProvider implements TokenProvider {
  @override
  String? get token => null;
}

Future<FakeAdapter> _setupFakeApi() async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.baseUrl: 'https://jdforrepam.com',
  });
  final prefs = await SharedPreferences.getInstance();
  final api = await ApiClient.create(
    prefs: prefs,
    tokenProvider: _TestTokenProvider(),
    onAuthError: () {},
  );
  final adapter = FakeAdapter();
  api.setAdapterForTest(adapter);
  return adapter;
}

String? _clipboardText;

void _mockClipboard(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        _clipboardText = call.arguments['text'] as String?;
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    _clipboardText = null;
  });
}

/// 期望的折叠态可见前缀：追加省略号后仍能在 maxLines 行内排版的最长前缀。
/// 与生产实现算法一致、独立计算，用于校验“全选复制”不包含省略号后的隐藏文本。
String _expectedVisiblePrefix(
  String text,
  TextStyle? style,
  int maxLines,
  double maxWidth,
  TextScaler textScaler,
) {
  bool fits(int count) {
    final painter = TextPainter(
      text: TextSpan(text: '${text.substring(0, count)}…', style: style),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final ok = !painter.didExceedMaxLines;
    painter.dispose();
    return ok;
  }

  var low = 0;
  var high = text.length;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (fits(mid)) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return text.substring(0, low);
}

/// 渲染侧独立 oracle：折叠态 RenderParagraph 的省略号截断点。
/// 用渲染对象自身的映射结果计算可见前缀，与生产/期望的二分探测互相校验。
String _renderedVisiblePrefix(RenderParagraph paragraph, String text) {
  final position = paragraph.getPositionForOffset(
    Offset(paragraph.size.width - 1, paragraph.size.height - 1),
  );
  return text.substring(0, position.offset);
}

void main() {
  testWidgets('有影片信息时渲染影片信息区', (tester) async {
    await tester.pumpWidget(_wrap(ReviewTile(review: _review(movie: _movie))));

    expect(find.text('ABC-001 / 2026-08-05'), findsOneWidget);
    expect(find.text('评论内容'), findsOneWidget);
    final title = tester.widget<Text>(
      find.text('这是一个非常长的影片标题需要省略显示最多两行'),
    );
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('无影片信息时不渲染影片信息区', (tester) async {
    await tester.pumpWidget(_wrap(ReviewTile(review: _review())));

    expect(find.text('ABC-001 / 2026-08-05'), findsNothing);
    expect(find.text('这是一个非常长的影片标题需要省略显示最多两行'), findsNothing);
    // 影片区不渲染，点赞行常驻为唯一 InkWell
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('无影片信息点击点赞提示无法点赞且不发请求', (tester) async {
    final auth = await _loggedInAuth();
    final adapter = await _setupFakeApi();
    await tester.pumpWidget(
      _wrapWithAuth(ReviewTile(review: _review()), auth),
    );

    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();

    expect(find.text('无法点赞'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('点击影片信息区跳转影片详情', (tester) async {
    final router = GoRouter(
      initialLocation: '/reviews',
      routes: [
        GoRoute(
          path: '/reviews',
          builder: (_, _) => Scaffold(
            body: ReviewTile(review: _review(movie: _movie)),
          ),
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (_, state) =>
              Scaffold(body: Text('影片 ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('这是一个非常长的影片标题需要省略显示最多两行'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/movie/m1');
    expect(find.text('影片 m1'), findsOneWidget);
  });

  testWidgets('短评论不显示展开收起按钮', (tester) async {
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(content: '短评论'))),
    );

    expect(find.text('短评论'), findsOneWidget);
    expect(find.text('展开'), findsNothing);
    expect(find.text('收起'), findsNothing);
  });

  testWidgets('超 5 行评论截断并可展开收起', (tester) async {
    final longText = '这是一段非常长的评论内容。' * 30;
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(content: longText))),
    );

    final collapsed = tester.widget<Text>(find.text(longText));
    expect(collapsed.maxLines, 5);
    expect(collapsed.overflow, TextOverflow.ellipsis);
    expect(find.text('展开'), findsOneWidget);

    await tester.tap(find.text('展开'));
    await tester.pump();

    final expanded = tester.widget<Text>(find.text(longText));
    expect(expanded.maxLines, isNull);
    expect(expanded.overflow, isNull);
    expect(find.text('收起'), findsOneWidget);

    await tester.tap(find.text('收起'));
    await tester.pump();

    final collapsedAgain = tester.widget<Text>(find.text(longText));
    expect(collapsedAgain.maxLines, 5);
    expect(collapsedAgain.overflow, TextOverflow.ellipsis);
    expect(find.text('展开'), findsOneWidget);
  });

  testWidgets('点击正文展开收起，点击影片信息区跳转', (tester) async {
    final longText = '这是一段非常长的评论内容。' * 30;
    final router = GoRouter(
      initialLocation: '/reviews',
      routes: [
        GoRoute(
          path: '/reviews',
          builder: (_, _) => Scaffold(
            body: ReviewTile(review: _review(movie: _movie, content: longText)),
          ),
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (_, state) =>
              Scaffold(body: Text('影片 ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    // 点击正文展开
    await tester.tap(find.text('展开'));
    await tester.pump();
    final expanded = tester.widget<Text>(find.text(longText));
    expect(expanded.maxLines, isNull);

    // 点击影片标题跳转
    await tester.tap(find.text('这是一个非常长的影片标题需要省略显示最多两行'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/movie/m1');
  });

  testWidgets('点击作者行不跳转', (tester) async {
    final router = GoRouter(
      initialLocation: '/reviews',
      routes: [
        GoRoute(
          path: '/reviews',
          builder: (_, _) =>
              Scaffold(body: ReviewTile(review: _review(movie: _movie))),
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (_, state) =>
              Scaffold(body: Text('影片 ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('作者A'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(router.state.uri.path, '/reviews');
  });

  testWidgets('点击评论正文展开收起', (tester) async {
    final longText = '这是一段非常长的评论内容。' * 30;
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(content: longText))),
    );

    final collapsed = tester.widget<Text>(find.text(longText));
    expect(collapsed.maxLines, 5);

    // 点击正文（非按钮）展开
    await tester.tapAt(
      tester.getCenter(find.text(longText)).translate(0, -20),
    );
    await tester.pump();

    final expanded = tester.widget<Text>(find.text(longText));
    expect(expanded.maxLines, isNull);

    // 再点收起
    await tester.tapAt(
      tester.getCenter(find.text(longText)).translate(0, -20),
    );
    await tester.pump();

    final collapsedAgain = tester.widget<Text>(find.text(longText));
    expect(collapsedAgain.maxLines, 5);
  });

  testWidgets('点击展开收起按钮仍可用', (tester) async {
    final longText = '这是一段非常长的评论内容。' * 30;
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(content: longText))),
    );

    await tester.tap(find.text('展开'));
    await tester.pump();
    expect(find.text('收起'), findsOneWidget);

    await tester.tap(find.text('收起'));
    await tester.pump();
    expect(find.text('展开'), findsOneWidget);
  });

  testWidgets('未登录点击点赞提示登录且不发请求', (tester) async {
    final auth = await _loggedOutAuth();
    final adapter = await _setupFakeApi();
    await tester.pumpWidget(
      _wrapWithAuth(ReviewTile(review: _review(movie: _movie)), auth),
    );

    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();

    expect(find.text('请先登录'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('无 Provider 包裹点击点赞按未登录处理不崩溃', (tester) async {
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(movie: _movie))),
    );

    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();

    expect(find.text('请先登录'), findsOneWidget);
  });

  testWidgets('已登录点赞成功数字加一且图标变实心', (tester) async {
    final auth = await _loggedInAuth();
    final adapter = await _setupFakeApi();
    adapter.enqueue(
      '/api/v1/movies/m1/reviews/r1/like',
      {'success': 1, 'data': null},
    );

    await tester.pumpWidget(
      _wrapWithAuth(
        ReviewTile(review: _review(movie: _movie)),
        auth,
      ),
    );

    expect(find.text('17'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('18'), findsOneWidget);
    expect(find.byKey(const Key('review-liked-icon')), findsOneWidget);
  });

  testWidgets('点赞中防连点：请求未返回时再点不触发第二次请求', (tester) async {
    final auth = await _loggedInAuth();
    final adapter = await _setupFakeApi();
    adapter.responseDelay = const Duration(seconds: 2);
    adapter.enqueue(
      '/api/v1/movies/m1/reviews/r1/like',
      {'success': 1, 'data': null},
    );

    await tester.pumpWidget(
      _wrapWithAuth(
        ReviewTile(review: _review(movie: _movie)),
        auth,
      ),
    );

    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump(const Duration(milliseconds: 100));
    // 请求在途（responseDelay 2s 未到），再次点击应被 _liking 守卫忽略
    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.requests, hasLength(1));

    // 推进请求完成
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(adapter.requests, hasLength(1));
    expect(find.text('18'), findsOneWidget);
  });

  testWidgets('已点赞评论点击无效果', (tester) async {
    final auth = await _loggedInAuth();
    final adapter = await _setupFakeApi();
    adapter.enqueue(
      '/api/v1/movies/m1/reviews/r1/like',
      {'success': 1, 'data': null},
    );
    await tester.pumpWidget(
      _wrapWithAuth(
        ReviewTile(
          review: _review(movie: _movie, liked: true),
        ),
        auth,
      ),
    );

    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('17'), findsOneWidget);
    expect(find.byKey(const Key('review-liked-icon')), findsOneWidget);
    expect(find.text('你已经点过赞了'), findsNothing);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('点赞失败提示且数字不变', (tester) async {
    final auth = await _loggedInAuth();
    final adapter = await _setupFakeApi();
    adapter.enqueue(
      '/api/v1/movies/m1/reviews/r1/like',
      {'success': 0, 'message': '失败'},
    );

    await tester.pumpWidget(
      _wrapWithAuth(ReviewTile(review: _review(movie: _movie)), auth),
    );

    await tester.tap(find.byKey(const Key('review-like-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('你已经点过赞了'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
  });

  testWidgets('长按短评正文进入选择态并展示复制全选菜单', (tester) async {
    await tester.pumpWidget(_wrap(ReviewTile(review: _review())));

    await tester.longPress(find.text('评论内容'));
    await tester.pumpAndSettle();

    expect(find.text('复制'), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
  });

  testWidgets('长按选中文本点击复制后剪贴板为所选文本且菜单关闭', (tester) async {
    _mockClipboard(tester);
    await tester.pumpWidget(_wrap(ReviewTile(review: _review())));

    await tester.longPress(find.text('评论内容'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    // 中文按字分词，长按仅选中长按处的单个汉字。
    expect(_clipboardText, isNotNull);
    expect('评论内容'.contains(_clipboardText!), isTrue);
    expect(find.text('复制'), findsNothing);
  });

  testWidgets('长按拉丁单词复制完整单词', (tester) async {
    _mockClipboard(tester);
    await tester.pumpWidget(_wrap(ReviewTile(review: _review(content: 'flutter'))));

    await tester.longPress(find.text('flutter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    expect(_clipboardText, 'flutter');
  });

  testWidgets('折叠态全选复制全部可见文本', (tester) async {
    _mockClipboard(tester);
    final longText = '这是一段非常长的评论内容。' * 30;
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(content: longText))),
    );

    await tester.longPress(find.text(longText));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    final box = tester.renderObject<RenderBox>(find.text(longText));
    final style = Theme.of(
      tester.element(find.text(longText)),
    ).textTheme.bodyLarge;
    final expected = _expectedVisiblePrefix(
      longText,
      style,
      5,
      box.constraints.maxWidth,
      TextScaler.noScaling,
    );
    expect(_clipboardText, expected);
    expect(_clipboardText!.length, lessThan(longText.length));
    // 渲染侧独立 oracle 交叉校验：与生产二分探测互证。
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(longText), matching: find.byType(RichText)),
    );
    expect(_clipboardText, _renderedVisiblePrefix(paragraph, longText));
  });

  testWidgets('折叠态长按复制所选可见文本', (tester) async {
    _mockClipboard(tester);
    final longText = List.generate(120, (i) => '词$i').join(' ');
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(content: longText))),
    );

    await tester.longPress(find.text(longText));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    final box = tester.renderObject<RenderBox>(find.text(longText));
    final style = Theme.of(
      tester.element(find.text(longText)),
    ).textTheme.bodyLarge;
    final visiblePrefix = _expectedVisiblePrefix(
      longText,
      style,
      5,
      box.constraints.maxWidth,
      TextScaler.noScaling,
    );
    expect(_clipboardText, isNotNull);
    expect(_clipboardText, isNot(longText));
    expect(visiblePrefix.contains(_clipboardText!), isTrue);
  });

  testWidgets('展开态全选复制全部文本', (tester) async {
    _mockClipboard(tester);
    final longText = '这是一段非常长的评论内容。' * 30;
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(content: longText))),
    );

    await tester.tap(find.text('展开'));
    await tester.pump();
    await tester.longPress(find.text(longText));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    expect(_clipboardText, longText);
  });

  testWidgets('系统字体缩放下折叠态全选复制全部可见文本', (tester) async {
    _mockClipboard(tester);
    final longText = '这是一段非常长的评论内容。' * 30;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: ReviewTile(review: _review(content: longText)),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text(longText));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    final box = tester.renderObject<RenderBox>(find.text(longText));
    final style = Theme.of(
      tester.element(find.text(longText)),
    ).textTheme.bodyLarge;
    final expected = _expectedVisiblePrefix(
      longText,
      style,
      5,
      box.constraints.maxWidth,
      TextScaler.linear(1.3),
    );
    expect(_clipboardText, expected);
    expect(_clipboardText!.length, lessThan(longText.length));
  });

  testWidgets('选中文字后点击正文仅清除选择不触发展开收起', (tester) async {
    final longText = '这是一段非常长的评论内容。' * 30;
    await tester.pumpWidget(
      _wrap(ReviewTile(review: _review(content: longText))),
    );

    final center = tester.getCenter(find.text(longText));
    await tester.longPressAt(center.translate(0, -30));
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsOneWidget);

    await tester.tapAt(center.translate(0, 30));
    await tester.pumpAndSettle();

    expect(find.text('复制'), findsNothing);
    expect(find.text('展开'), findsOneWidget);
  });
}
