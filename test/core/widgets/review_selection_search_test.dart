import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/code.dart';
import 'package:jade/core/models/director.dart';
import 'package:jade/core/models/list_model.dart';
import 'package:jade/core/models/maker.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/models/series.dart';
import 'package:jade/core/widgets/review_tile.dart';
import 'package:jade/core/widgets/selectable_copy_search_text.dart';
import 'package:jade/features/movie_detail/models/movie_review_sort.dart';
import 'package:jade/features/movie_detail/widgets/movie_detail_lists.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';
import 'package:jade/features/search/screens/search_results_screen.dart';
import 'package:jade/features/search/services/search_entity_service.dart';
import 'package:jade/features/search/services/search_history_store.dart';
import 'package:jade/features/search/services/search_movie_service.dart';
import 'package:jade/router/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

Review _review({String content = '评论内容'}) => Review(
  id: 'r1',
  author: const ReviewAuthor(name: '作者A'),
  watchedCount: 3,
  score: 4.5,
  content: content,
  likedCount: 17,
  liked: false,
  createdAt: '2016-09-24',
);

class _RecordingMovieDataSource implements SearchMovieDataSource {
  final queries = <String>[];

  @override
  Future<PagedResult<MovieSummary>> getMovies({
    required String query,
    required SearchMovieFilter filter,
    int page = 1,
  }) async {
    queries.add(query);
    return const PagedResult<MovieSummary>(
      items: [],
      currentPage: 1,
      totalPages: 1,
      total: 0,
    );
  }
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

GoRouter _buildRouter({
  required Widget home,
  required SearchHistoryStore store,
  _RecordingMovieDataSource? movies,
}) => GoRouter(
  initialLocation: AppRoutes.reviews,
  routes: [
    GoRoute(path: AppRoutes.reviews, builder: (_, _) => home),
    GoRoute(
      path: AppRoutes.searchResults,
      builder: (_, state) => SearchResultsScreen(
        key: ValueKey(state.uri),
        query: state.uri.queryParameters['q']!.trim(),
        historyStore: store,
        movieDataSource: movies ?? _RecordingMovieDataSource(),
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

void main() {
  testWidgets('长按评论正文的操作菜单包含复制、搜索与全选', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReviewTile(review: _review())),
      ),
    );

    await tester.longPress(find.text('评论内容'));
    await tester.pumpAndSettle();

    expect(find.text('复制'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
  });

  testWidgets('搜索以规范化后的选中文本为关键词进入结果页并记录历史', (tester) async {
    final store = await _newHistoryStore();
    final movies = _RecordingMovieDataSource();
    const content = '你好   世界\n第二行';
    final router = _buildRouter(
      home: Scaffold(
        body: ReviewTile(review: _review(content: content)),
      ),
      store: store,
      movies: movies,
    );
    await _pumpRouter(tester, router);

    await tester.longPressAt(
      tester.getTopLeft(find.text(content)) + const Offset(20, 12),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('搜索'));
    await _flush(tester);

    const keyword = '你好 世界 第二行';
    expect(router.state.uri.path, AppRoutes.searchResults);
    expect(router.state.uri.queryParameters['q'], keyword);
    expect(find.text(keyword), findsOneWidget);
    expect(movies.queries, contains(keyword));
    expect(store.load().first, keyword);
  });

  testWidgets('折叠态搜索仅使用省略号之前的可见前缀', (tester) async {
    final store = await _newHistoryStore();
    final longText = '这是一段非常长的评论内容。' * 30;
    final router = _buildRouter(
      home: Scaffold(
        body: ReviewTile(review: _review(content: longText)),
      ),
      store: store,
    );
    await _pumpRouter(tester, router);

    await tester.longPress(find.text(longText));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(longText), matching: find.byType(RichText)),
    );
    final expected = longText.substring(
      0,
      paragraph
          .getPositionForOffset(
            Offset(paragraph.size.width - 1, paragraph.size.height - 1),
          )
          .offset,
    );
    expect(expected.length, lessThan(longText.length));

    await tester.tap(find.text('搜索'));
    await _flush(tester);

    expect(router.state.uri.queryParameters['q'], expected);
  });

  testWidgets('选中内容规范化后为空时搜索不跳转', (tester) async {
    final store = await _newHistoryStore();
    final router = _buildRouter(
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: SelectableCopySearchText(
            text: '   ',
            style: TextStyle(fontSize: 32),
          ),
        ),
      ),
      store: store,
    );
    await _pumpRouter(tester, router);

    await tester.longPress(find.text('   '));
    await tester.pumpAndSettle();
    if (find.text('全选').evaluate().isNotEmpty) {
      await tester.tap(find.text('全选'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.reviews);
    expect(find.text('   '), findsOneWidget);
  });

  testWidgets('从结果页返回后评论展开状态与滚动位置保持', (tester) async {
    final store = await _newHistoryStore();
    final longText = '这是一段非常长的评论内容。' * 30;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final router = _buildRouter(
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            const SizedBox(height: 120),
            ReviewTile(review: _review(content: longText)),
            const SizedBox(height: 2000),
          ],
        ),
      ),
      store: store,
    );
    await _pumpRouter(tester, router);

    await tester.tap(find.text('展开'));
    await tester.pumpAndSettle();
    controller.jumpTo(80);
    await tester.pump();
    final offsetBefore = controller.offset;

    final rect = tester.getRect(find.text(longText));
    await tester.longPressAt(Offset(rect.left + 24, rect.top + 8));
    await tester.pumpAndSettle();
    expect(find.text('搜索'), findsOneWidget);
    await tester.tap(find.text('搜索'));
    await _flush(tester);
    expect(router.state.uri.path, AppRoutes.searchResults);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('收起'), findsOneWidget);
    expect(controller.offset, offsetBefore);
  });

  testWidgets('影片详情页短评列表同样提供搜索菜单项', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MovieReviewList(
            reviews: [_review()],
            loading: false,
            sort: MovieReviewSort.recently,
            onSortChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.longPress(find.text('评论内容'));
    await tester.pumpAndSettle();

    expect(find.text('搜索'), findsOneWidget);
  });
}
