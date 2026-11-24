import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/features/movie_detail/widgets/movie_detail_title_bar.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';
import 'package:jade/features/search/screens/search_results_screen.dart';
import 'package:jade/features/search/services/search_entity_service.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:jade/features/search/services/search_movie_service.dart';
import 'package:jade/router/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 标题包含连续空格，用于验证搜索关键词的空白折叠。
const _title = 'SSIS-123  这是一个  需要多行展示才能完整显示的影片标题';
const _titleTextKey = Key('movie-detail-title-text');
const _collapsedTitleTextKey = Key('movie-detail-title-text-collapsed');
const _titleBarKey = Key('movie-detail-title-bar');

class _EmptyMovieDataSource implements SearchMovieDataSource {
  const _EmptyMovieDataSource();

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  }) async => const PagedResult<MovieSummary>(
    items: [],
    currentPage: 1,
    totalPages: 1,
    total: 0,
  );
}

class _EmptyEntityDataSource implements SearchEntityDataSource {
  const _EmptyEntityDataSource();

  @override
  Future<PagedResult<ActorSummary>> getActors({
    required String query,
    int page = 1,
  }) async => const PagedResult<ActorSummary>(
    items: [],
    currentPage: 1,
    totalPages: 1,
    total: 0,
  );

  @override
  Future<PagedResult<Series>> getSeries({
    required String query,
    int page = 1,
  }) async => const PagedResult<Series>(
    items: [],
    currentPage: 1,
    totalPages: 1,
    total: 0,
  );

  @override
  Future<PagedResult<Maker>> getMakers({
    required String query,
    int page = 1,
  }) async => const PagedResult<Maker>(
    items: [],
    currentPage: 1,
    totalPages: 1,
    total: 0,
  );

  @override
  Future<PagedResult<Director>> getDirectors({
    required String query,
    int page = 1,
  }) async => const PagedResult<Director>(
    items: [],
    currentPage: 1,
    totalPages: 1,
    total: 0,
  );

  @override
  Future<PagedResult<ListModel>> getLists({
    required String query,
    int page = 1,
  }) async => const PagedResult<ListModel>(
    items: [],
    currentPage: 1,
    totalPages: 1,
    total: 0,
  );

  @override
  Future<PagedResult<Code>> getCodes({
    required String query,
    int page = 1,
  }) async => const PagedResult<Code>(
    items: [],
    currentPage: 1,
    totalPages: 1,
    total: 0,
  );
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _detailBody({String title = _title}) {
  return Scaffold(
    body: CustomScrollView(
      slivers: [
        MovieDetailTitleBar(title: title),
        const SliverToBoxAdapter(child: SizedBox(height: 2000)),
      ],
    ),
  );
}

Widget _buildHarness({String title = _title}) {
  return MaterialApp(home: _detailBody(title: title));
}

GoRouter _buildRouter({
  required Widget home,
  required SearchHistoryStore store,
}) => GoRouter(
  initialLocation: '/movie/m1',
  routes: [
    GoRoute(path: AppRoutes.movieDetail, builder: (_, _) => home),
    GoRoute(
      path: AppRoutes.searchResults,
      builder: (_, state) => SearchResultsScreen(
        key: ValueKey(state.uri),
        query: state.uri.queryParameters['q']!.trim(),
        historyStore: store,
        movieDataSource: const _EmptyMovieDataSource(),
        entityDataSource: const _EmptyEntityDataSource(),
      ),
    ),
  ],
);

Future<SearchHistoryStore> _newHistoryStore() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return SearchHistoryStore(prefs);
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

/// 结果页含封面占位动画，无法 pumpAndSettle，用固定节奏推进帧。
Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

ScrollableState _scrollable(WidgetTester tester) {
  return tester.state<ScrollableState>(find.byType(Scrollable).first);
}

/// 记录剪贴板写入，返回读取已写入文本的函数。
List<String> _mockClipboard(WidgetTester tester) {
  final writes = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = call.arguments as Map<Object?, Object?>;
        writes.add(arguments['text']! as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return writes;
}

/// 在标题文本的可见区域（最后一行）长按，避免命中被裁剪的隐藏部分。
Future<void> _longPressTitle(WidgetTester tester, Key key) async {
  final rect = tester.getRect(find.byKey(key));
  await tester.longPressAt(Offset(rect.left + 40, rect.bottom - 12));
  await tester.pumpAndSettle();
}

Future<void> _selectAll(WidgetTester tester) async {
  await tester.tap(find.text('全选'));
  await tester.pumpAndSettle();
}

/// 折叠态标题渲染出的可见前缀（与省略号截断点一致）。
String _renderedVisiblePrefix(WidgetTester tester, Key key) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.byKey(key), matching: find.byType(RichText)),
  );
  final offset = paragraph
      .getPositionForOffset(
        Offset(paragraph.size.width - 1, paragraph.size.height - 1),
      )
      .offset;
  return _title.substring(0, offset);
}

void main() {
  testWidgets('长按展开态标题展示复制、搜索与全选菜单', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness());

    await _longPressTitle(tester, _titleTextKey);

    expect(find.text('复制'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
  });

  testWidgets('复制所选标题写入剪贴板且菜单关闭', (tester) async {
    _usePhoneSize(tester);
    final clipboard = _mockClipboard(tester);
    await tester.pumpWidget(_buildHarness());

    await _longPressTitle(tester, _titleTextKey);
    await _selectAll(tester);
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    expect(clipboard, [_title]);
    expect(find.text('复制'), findsNothing);
  });

  testWidgets('搜索以规范化后的标题为关键词进入结果页', (tester) async {
    _usePhoneSize(tester);
    final store = await _newHistoryStore();
    final router = _buildRouter(home: _detailBody(), store: store);
    await _pumpRouter(tester, router);

    await _longPressTitle(tester, _titleTextKey);
    await _selectAll(tester);
    await tester.tap(find.text('搜索'));
    await _flush(tester);

    const keyword = 'SSIS-123 这是一个 需要多行展示才能完整显示的影片标题';
    expect(router.state.uri.path, AppRoutes.searchResults);
    expect(router.state.uri.queryParameters['q'], keyword);
    expect(find.text(keyword), findsOneWidget);
  });

  testWidgets('收起态全选复制与搜索仅使用可见前缀', (tester) async {
    _usePhoneSize(tester);
    final clipboard = _mockClipboard(tester);
    final store = await _newHistoryStore();
    final router = _buildRouter(home: _detailBody(), store: store);
    await _pumpRouter(tester, router);

    final position = _scrollable(tester).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(find.byKey(_collapsedTitleTextKey), findsOneWidget);

    final expected = _renderedVisiblePrefix(tester, _collapsedTitleTextKey);
    expect(expected.length, lessThan(_title.length));
    expect(_title.startsWith(expected), isTrue);

    await _longPressTitle(tester, _collapsedTitleTextKey);
    await _selectAll(tester);
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(clipboard, [expected]);

    await _longPressTitle(tester, _collapsedTitleTextKey);
    await _selectAll(tester);
    await tester.tap(find.text('搜索'));
    await _flush(tester);

    expect(
      router.state.uri.queryParameters['q'],
      expected.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
  });

  testWidgets('展开态被截断的极端超长标题同样只使用可见前缀', (tester) async {
    _usePhoneSize(tester);
    final clipboard = _mockClipboard(tester);
    final longTitle = 'SSIS-123 ${'这是一段很长的标题文案' * 40}';
    await tester.pumpWidget(_buildHarness(title: longTitle));

    final expanded = tester.widget<Text>(
      find.descendant(
        of: find.byKey(_titleTextKey),
        matching: find.byType(Text),
      ),
    );
    expect(expanded.maxLines, lessThan(100));

    await _longPressTitle(tester, _titleTextKey);
    await _selectAll(tester);
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    expect(clipboard, hasLength(1));
    final copied = clipboard.single;
    expect(copied.length, lessThan(longTitle.length));
    expect(longTitle.startsWith(copied), isTrue);
  });

  testWidgets('在标题上垂直拖动仍滚动页面', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness());
    final position = _scrollable(tester).position;
    expect(position.pixels, 0);

    await tester.drag(find.byKey(_titleTextKey), const Offset(0, -200));
    await tester.pump();

    expect(position.pixels, greaterThan(0));
    expect(find.text('复制'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未选中时点击标题无附加动作', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness());
    final position = _scrollable(tester).position;

    await tester.tap(find.byKey(_titleTextKey));
    await tester.pumpAndSettle();

    expect(position.pixels, 0);
    expect(find.text('复制'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('收起态返回按钮仍可点击返回', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _detailBody(),
                  ),
                ),
                child: const Text('打开详情'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();

    final position = _scrollable(tester).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(find.byKey(_collapsedTitleTextKey), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('打开详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('标题栏既有折叠与展开高度不变', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness());
    final expandedHeight = tester.getSize(find.byType(AppBar)).height;
    expect(expandedHeight, greaterThan(kToolbarHeight));

    final position = _scrollable(tester).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(
      tester.getSize(find.byType(AppBar)).height,
      closeTo(kToolbarHeight, 0.01),
    );

    position.jumpTo(0);
    await tester.pump();
    expect(
      tester.getSize(find.byType(AppBar)).height,
      closeTo(expandedHeight, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('空标题不抛异常且不提供可选文本', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_buildHarness(title: ''));
    expect(find.byKey(_titleBarKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
