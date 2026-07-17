import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/widgets/movie_card.dart';

void main() {
  testWidgets('MovieCard 渲染封面标题番号', (tester) async {
    final movie = MovieSummary(
      id: '1', number: 'SSIS-001', title: 'Test Movie', coverUrl: 'covers/x.jpg',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MovieCard(movie: movie)),
    ));
    expect(find.text('Test Movie'), findsOneWidget);
    expect(find.text('SSIS-001'), findsOneWidget);
  });

  testWidgets('MovieCard onTap 回调', (tester) async {
    var tapped = false;
    final movie = MovieSummary(
      id: '1', number: 'ABC-001', title: 'Tap Me', coverUrl: 'x.jpg',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MovieCard(movie: movie, onTap: () => tapped = true)),
    ));
    await tester.tap(find.text('Tap Me'));
    expect(tapped, isTrue);
  });
}
