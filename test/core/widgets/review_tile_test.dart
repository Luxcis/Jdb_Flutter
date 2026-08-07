import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/core/widgets/review_tile.dart';

Review _review({ReviewMovie? movie, String content = '评论内容'}) => Review(
  id: '1',
  author: const ReviewAuthor(name: '作者A'),
  watchedCount: 3,
  score: 4.5,
  content: content,
  likedCount: 17,
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

  testWidgets('无影片信息时不渲染影片信息区且不可点击', (tester) async {
    await tester.pumpWidget(_wrap(ReviewTile(review: _review())));

    expect(find.text('ABC-001 / 2026-08-05'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('点击卡片跳转影片详情', (tester) async {
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

    await tester.tap(find.byType(InkWell));
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
}
