import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/features/movie_detail/widgets/movie_review_actions.dart';

Future<void> pumpActions(
  WidgetTester tester, {
  Review? review,
  bool loading = false,
  VoidCallback? onWantWatch,
  VoidCallback? onWatched,
  VoidCallback? onDelete,
  VoidCallback? onSaveToList,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MovieReviewActions(
          review: review,
          loading: loading,
          onWantWatch: onWantWatch ?? () {},
          onWatched: onWatched ?? () {},
          onDelete: onDelete ?? () {},
          onSaveToList: onSaveToList ?? () {},
        ),
      ),
    ),
  );
}

List<String> buttonLabels(WidgetTester tester) {
  return tester
      .widgetList<FilledButton>(find.byType(FilledButton))
      .map((button) => (button.child as Text).data!)
      .toList();
}

void main() {
  testWidgets('未标记时按想看看过存入清单排序', (tester) async {
    await pumpActions(tester);
    expect(buttonLabels(tester), ['想看', '看过', '存入清单']);
    expect(
      tester.getTopLeft(find.text('想看')).dx,
      lessThan(tester.getTopLeft(find.text('存入清单')).dx),
    );
    expect(
      tester.getTopLeft(find.text('看过')).dx,
      lessThan(tester.getTopLeft(find.text('存入清单')).dx),
    );
  });

  testWidgets('想看状态显示删除想看看过存入清单', (tester) async {
    await pumpActions(
      tester,
      review: const Review(id: 'r1', status: 'want_watch'),
    );
    expect(buttonLabels(tester), ['删除想看', '看过', '存入清单']);
  });

  testWidgets('看过状态只显示删除看过和存入清单', (tester) async {
    await pumpActions(
      tester,
      review: const Review(id: 'r2', status: 'watched'),
    );
    expect(buttonLabels(tester), ['删除看过', '存入清单']);
  });

  testWidgets('未知影评状态回退为未标记操作', (tester) async {
    await pumpActions(
      tester,
      review: const Review(id: 'r3', status: 'unknown'),
    );
    expect(buttonLabels(tester), ['想看', '看过', '存入清单']);
  });

  testWidgets('加载时只禁用影评操作而保留存入清单', (tester) async {
    await pumpActions(tester, loading: true);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('movie-want-watch-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('movie-watched-button')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('movie-save-to-list-button')),
          )
          .onPressed,
      isNotNull,
    );

    await pumpActions(
      tester,
      review: const Review(id: 'r1', status: 'want_watch'),
      loading: true,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('movie-delete-want-watch-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('movie-watched-button')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('movie-save-to-list-button')),
          )
          .onPressed,
      isNotNull,
    );

    await pumpActions(
      tester,
      review: const Review(id: 'r2', status: 'watched'),
      loading: true,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('movie-delete-watched-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('movie-save-to-list-button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('窄宽度下默认操作通过 Wrap 换行且无溢出', (tester) async {
    final errors = <FlutterError>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(FlutterError(details.exceptionAsString()));
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: MovieReviewActions(
              review: null,
              loading: false,
              onWantWatch: () {},
              onWatched: () {},
              onDelete: () {},
              onSaveToList: () {},
            ),
          ),
        ),
      ),
    );

    expect(errors, isEmpty);
    final topPositions = [
      tester.getTopLeft(find.byKey(const Key('movie-want-watch-button'))).dy,
      tester.getTopLeft(find.byKey(const Key('movie-watched-button'))).dy,
      tester.getTopLeft(find.byKey(const Key('movie-save-to-list-button'))).dy,
    ];
    expect(topPositions.toSet().length, greaterThan(1));
  });

  testWidgets('可见按钮 key 均调用对应 callback', (tester) async {
    final calls = <String>[];
    await pumpActions(
      tester,
      onWantWatch: () => calls.add('want_watch'),
      onWatched: () => calls.add('watched'),
      onSaveToList: () => calls.add('save'),
    );

    await tester.tap(find.byKey(const Key('movie-want-watch-button')));
    await tester.tap(find.byKey(const Key('movie-watched-button')));
    await tester.tap(find.byKey(const Key('movie-save-to-list-button')));

    expect(calls, ['want_watch', 'watched', 'save']);

    calls.clear();
    await pumpActions(
      tester,
      review: const Review(id: 'r1', status: 'want_watch'),
      onDelete: () => calls.add('delete'),
      onWatched: () => calls.add('watched'),
      onSaveToList: () => calls.add('save'),
    );

    await tester.tap(find.byKey(const Key('movie-delete-want-watch-button')));
    await tester.tap(find.byKey(const Key('movie-watched-button')));
    await tester.tap(find.byKey(const Key('movie-save-to-list-button')));

    expect(calls, ['delete', 'watched', 'save']);

    calls.clear();
    await pumpActions(
      tester,
      review: const Review(id: 'r2', status: 'watched'),
      onDelete: () => calls.add('delete'),
      onSaveToList: () => calls.add('save'),
    );
    await tester.tap(find.byKey(const Key('movie-delete-watched-button')));
    await tester.tap(find.byKey(const Key('movie-save-to-list-button')));

    expect(calls, ['delete', 'save']);
  });
}
