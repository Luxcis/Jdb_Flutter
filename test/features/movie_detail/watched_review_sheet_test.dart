import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/star_rating.dart';
import 'package:jade/features/movie_detail/widgets/watched_review_sheet.dart';

void main() {
  testWidgets('评论输入框公开为多行句子输入并使用换行操作', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatchedReviewSheet(
            onSubmit: ({required score, required content}) async {},
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(
      find.byKey(const Key('watched-review-content-field')),
    );
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textInputAction, TextInputAction.newline);
    expect(field.textCapitalization, TextCapitalization.sentences);
    expect(field.minLines, 3);
    expect(field.maxLines, 5);
  });

  testWidgets('评分和非空评论都满足后才允许提交', (tester) async {
    ({int score, String content})? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open-watched-review-sheet'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => WatchedReviewSheet(
                  onSubmit: ({required score, required content}) async {
                    submitted = (score: score, content: content);
                  },
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-watched-review-sheet')));
    await tester.pumpAndSettle();

    FilledButton submitButton() =>
        tester.widget(find.byKey(const Key('watched-review-submit-button')));

    expect(submitButton().onPressed, isNull);
    await tester.tap(find.byKey(const Key('star-rating-3')));
    await tester.pump();
    expect(submitButton().onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('watched-review-content-field')),
      '  评论内容  ',
    );
    await tester.pump();
    expect(submitButton().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('watched-review-submit-button')));
    await tester.pumpAndSettle();
    expect(submitted, (score: 3, content: '评论内容'));
    expect(find.byType(WatchedReviewSheet), findsNothing);
  });

  testWidgets('提交期间禁用表单且重复点击只提交一次', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatchedReviewSheet(
            onSubmit: ({required score, required content}) {
              calls++;
              return completer.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('star-rating-4')));
    await tester.enterText(
      find.byKey(const Key('watched-review-content-field')),
      '评论',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('watched-review-submit-button')));
    await tester.tap(find.byKey(const Key('watched-review-submit-button')));
    await tester.pump();

    expect(calls, 1);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('watched-review-content-field')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<StarRating>(find.byKey(const Key('watched-review-rating')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('watched-review-cancel-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('watched-review-submit-button')),
          )
          .onPressed,
      isNull,
    );

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('提交失败保留评分评论并允许重试', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatchedReviewSheet(
            onSubmit: ({required score, required content}) async {
              throw StateError('failed');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('star-rating-2')));
    await tester.enterText(
      find.byKey(const Key('watched-review-content-field')),
      '保留的评论',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('watched-review-submit-button')));
    await tester.pump();

    expect(find.text('操作失败，请重试'), findsOneWidget);
    expect(find.text('保留的评论'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('watched-review-submit-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.byType(WatchedReviewSheet), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
  });
}
