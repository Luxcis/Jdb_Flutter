import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/home/widgets/recommend_carousel.dart';

const movies = [
  MovieSummary(id: 'a', number: 'A-1', title: 'A', coverUrl: ''),
  MovieSummary(id: 'b', number: 'B-1', title: 'B', coverUrl: ''),
  MovieSummary(id: 'c', number: 'C-1', title: 'C', coverUrl: ''),
];

Future<void> pumpCarousel(
  WidgetTester tester, {
  List<MovieSummary> items = movies,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 220,
          child: RecommendCarousel(movies: items, onMovieTap: (_) {}),
        ),
      ),
    ),
  );
}

Future<void> finishAutoPlayAnimation(WidgetTester tester) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> finishManualSwipe(WidgetTester tester) async {
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void expectVisibleTitle(WidgetTester tester, String title) {
  final carouselCenter = tester.getCenter(find.byType(CarouselSlider)).dx;
  final titleCenter = tester.getCenter(find.text(title)).dx;
  expect(titleCenter, closeTo(carouselCenter, 5));
}

void main() {
  testWidgets('佳片推荐由 CarouselSlider 承载', (tester) async {
    await pumpCarousel(tester);

    expect(find.byType(CarouselSlider), findsOneWidget);
  });

  testWidgets('满 5 秒后自动显示下一张推荐', (tester) async {
    await pumpCarousel(tester);
    expectVisibleTitle(tester, 'A');

    await tester.pump(const Duration(seconds: 3));
    await finishAutoPlayAnimation(tester);
    expectVisibleTitle(tester, 'A');
    await tester.pump(const Duration(milliseconds: 1599));
    expectVisibleTitle(tester, 'A');

    await tester.pump(const Duration(milliseconds: 1));
    await finishAutoPlayAnimation(tester);
    expectVisibleTitle(tester, 'B');
  });

  testWidgets('最后一张之后继续显示第一张', (tester) async {
    await pumpCarousel(tester);

    for (var index = 0; index < movies.length; index++) {
      await tester.pump(const Duration(seconds: 5));
      await finishAutoPlayAnimation(tester);
    }

    expectVisibleTitle(tester, 'A');
  });

  testWidgets('手动滑动后重新等待完整 5 秒', (tester) async {
    await pumpCarousel(tester);
    final carousel = find.byKey(const Key('home-recommend-carousel'));

    await tester.pump(const Duration(seconds: 4));
    await tester.drag(carousel, const Offset(-600, 0));
    await finishManualSwipe(tester);
    expectVisibleTitle(tester, 'B');

    await tester.pump(const Duration(milliseconds: 4399));
    expectVisibleTitle(tester, 'B');
    await tester.pump(const Duration(milliseconds: 1));
    await finishAutoPlayAnimation(tester);
    expectVisibleTitle(tester, 'C');
  });

  testWidgets('只有一张推荐时不会自动切换', (tester) async {
    await pumpCarousel(tester, items: [movies.first]);

    await tester.pump(const Duration(seconds: 15));

    expectVisibleTitle(tester, 'A');
  });

  testWidgets('应用在后台时暂停并在恢复后重新计时', (tester) async {
    await pumpCarousel(tester);
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    await tester.pump(const Duration(seconds: 10));
    await finishAutoPlayAnimation(tester);
    expectVisibleTitle(tester, 'A');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await finishAutoPlayAnimation(tester);
    expectVisibleTitle(tester, 'A');
    await tester.pump(const Duration(milliseconds: 1599));
    expectVisibleTitle(tester, 'A');
    await tester.pump(const Duration(milliseconds: 1));
    await finishAutoPlayAnimation(tester);
    expectVisibleTitle(tester, 'B');
  });

  testWidgets('TickerMode 关闭时暂停并在恢复后重新计时', (tester) async {
    Widget harness(bool enabled) => MaterialApp(
      home: TickerMode(
        enabled: enabled,
        child: Scaffold(
          body: SizedBox(
            height: 220,
            child: RecommendCarousel(movies: movies, onMovieTap: (_) {}),
          ),
        ),
      ),
    );

    await tester.pumpWidget(harness(true));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(harness(false));
    await tester.pump(const Duration(seconds: 10));
    await finishAutoPlayAnimation(tester);
    expectVisibleTitle(tester, 'A');

    await tester.pumpWidget(harness(true));
    await tester.pump(const Duration(milliseconds: 4999));
    expectVisibleTitle(tester, 'A');
    await tester.pump(const Duration(milliseconds: 1));
    await finishAutoPlayAnimation(tester);
    expectVisibleTitle(tester, 'B');
  });

  testWidgets('销毁轮播后没有异步异常', (tester) async {
    await pumpCarousel(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));

    expect(tester.takeException(), isNull);
  });
}
