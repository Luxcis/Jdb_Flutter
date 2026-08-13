import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_playback.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_header_overlay.dart';

MoviePreviewPlaybackState _state({
  bool playing = true,
  bool buffering = false,
  bool completed = false,
  String? error,
}) {
  return MoviePreviewPlaybackState(
    isInitialized: true,
    isPlaying: playing,
    isBuffering: buffering,
    isCompleted: completed,
    errorDescription: error,
  );
}

Widget _wrap(ValueNotifier<MoviePreviewPlaybackState> notifier) {
  return MaterialApp(
    home: MoviePreviewHeaderOverlay(
      title: '测试影片',
      onBack: () {},
      state: notifier,
    ),
  );
}

double _opacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(
        find.byKey(MoviePreviewHeaderOverlay.headerOpacityKey),
      )
      .opacity;
}

bool _ignoring(WidgetTester tester) {
  return tester
      .widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byKey(MoviePreviewHeaderOverlay.headerOpacityKey),
              matching: find.byType(IgnorePointer),
            )
            .first,
      )
      .ignoring;
}

void main() {
  testWidgets('渲染标题与返回按钮', (tester) async {
    final notifier = ValueNotifier(_state(playing: false));
    await tester.pumpWidget(_wrap(notifier));

    expect(find.text('测试影片'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(_opacity(tester), 1.0);

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('播放中 3 秒后隐藏', (tester) async {
    final notifier = ValueNotifier(_state());
    await tester.pumpWidget(_wrap(notifier));

    await tester.pump(const Duration(seconds: 2));
    expect(_opacity(tester), 1.0);

    await tester.pump(const Duration(seconds: 1));
    expect(_opacity(tester), 0.0);
    expect(_ignoring(tester), isTrue);

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('暂停立即显示', (tester) async {
    final notifier = ValueNotifier(_state());
    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(seconds: 3));
    expect(_opacity(tester), 0.0);

    notifier.value = _state(playing: false);
    await tester.pump();

    expect(_opacity(tester), 1.0);
    expect(_ignoring(tester), isFalse);

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('缓冲中不隐藏', (tester) async {
    final notifier = ValueNotifier(_state(buffering: true));
    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(seconds: 4));

    expect(_opacity(tester), 1.0);

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('完成态与错误态保持显示', (tester) async {
    for (final state in [
      _state(playing: false, completed: true),
      _state(playing: false, error: 'media error'),
    ]) {
      final notifier = ValueNotifier(state);
      await tester.pumpWidget(_wrap(notifier));
      await tester.pump(const Duration(seconds: 4));

      expect(_opacity(tester), 1.0);

      await tester.pumpWidget(const SizedBox());
      notifier.dispose();
    }
  });

  testWidgets('播放中同时携带完成或错误仍保持显示', (tester) async {
    for (final state in [
      _state(playing: true, completed: true),
      _state(playing: true, error: 'media error'),
    ]) {
      final notifier = ValueNotifier(state);
      await tester.pumpWidget(_wrap(notifier));
      await tester.pump(const Duration(seconds: 4));

      expect(_opacity(tester), 1.0);

      await tester.pumpWidget(const SizedBox());
      notifier.dispose();
    }
  });

  testWidgets('已隐藏后切入完成或错误立即显示', (tester) async {
    final notifier = ValueNotifier(_state());
    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(seconds: 3));
    expect(_opacity(tester), 0.0);

    for (final state in [
      _state(playing: true, completed: true),
      _state(playing: false, error: 'media error'),
    ]) {
      notifier.value = state;
      await tester.pump();

      expect(_opacity(tester), 1.0);
      expect(_ignoring(tester), isFalse);
    }

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('重新进入播放状态重新计时', (tester) async {
    final notifier = ValueNotifier(_state(playing: false));
    await tester.pumpWidget(_wrap(notifier));

    notifier.value = _state();
    await tester.pump(const Duration(seconds: 2));
    expect(_opacity(tester), 1.0);

    notifier.value = _state(playing: false);
    await tester.pump();
    notifier.value = _state();
    await tester.pump(const Duration(seconds: 2));
    expect(_opacity(tester), 1.0);

    await tester.pump(const Duration(seconds: 1));
    expect(_opacity(tester), 0.0);

    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });

  testWidgets('销毁时取消定时器不抛异常', (tester) async {
    final notifier = ValueNotifier(_state());
    await tester.pumpWidget(_wrap(notifier));
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
    notifier.dispose();
  });
}
