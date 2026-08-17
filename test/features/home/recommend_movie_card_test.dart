import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/movie_cover_image.dart';
import 'package:jade/features/home/widgets/recommend_movie_card.dart';

void main() {
  testWidgets('卡片占满整行宽且无默认外边距', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              RecommendMovieCard(
                movie: MovieSummary(
                  id: '1',
                  number: 'SSIS-001',
                  title: 'Test Movie',
                  coverUrl: 'covers/x.jpg',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.margin, EdgeInsets.zero);
    expect(
      tester.getRect(find.byType(RecommendMovieCard)).width,
      tester.getSize(find.byType(Scaffold)).width,
    );
  });

  testWidgets('卡片包含封面、标题与五星评分', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecommendMovieCard(
            movie: MovieSummary(
              id: '1',
              number: 'SSIS-001',
              title: 'Test Movie',
              coverUrl: 'covers/x.jpg',
              score: 7.5,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MovieCoverImage), findsOneWidget);
    expect(find.text('Test Movie'), findsOneWidget);
    final rating = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '评分 7.5 分',
      ),
    );
    expect(rating.properties.label, '评分 7.5 分');
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
  });

  testWidgets('点击卡片打开影片详情页', (tester) async {
    final movie = MovieSummary(
      id: 'movie-42',
      number: 'JDB-042',
      title: '默认导航影片',
      coverUrl: '',
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              Scaffold(body: RecommendMovieCard(movie: movie)),
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (context, state) =>
              Scaffold(body: Text('详情 ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byType(RecommendMovieCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(router.state.uri.path, '/movie/movie-42');
    expect(find.text('详情 movie-42'), findsOneWidget);
  });
}
