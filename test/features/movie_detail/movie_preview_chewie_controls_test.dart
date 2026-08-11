import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_chewie_controls.dart';
import 'package:video_player/video_player.dart';

class _ControlsVideoPlayerController extends VideoPlayerController {
  _ControlsVideoPlayerController()
    : super.networkUrl(
        Uri.parse('https://media.example.com/preview.m3u8'),
        formatHint: VideoFormat.hls,
      );

  @override
  Future<void> initialize() async {
    value = const VideoPlayerValue(
      duration: Duration(minutes: 1),
      size: Size(1920, 1080),
      isInitialized: true,
    );
  }

  @override
  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
  }
}

Future<({ChewieController chewie, VideoPlayerController video})> _pumpControls(
  WidgetTester tester, {
  required VoidCallback onBack,
}) async {
  final video = _ControlsVideoPlayerController();
  await video.initialize();
  await video.play();
  final chewie = ChewieController(
    videoPlayerController: video,
    autoInitialize: false,
    autoPlay: false,
    showControls: true,
    showControlsOnInitialize: true,
    hideControlsTimer: const Duration(seconds: 3),
    allowFullScreen: false,
    customControls: MoviePreviewChewieControls(title: '测试影片', onBack: onBack),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(child: Chewie(controller: chewie)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  return (chewie: chewie, video: video);
}

double _headerOpacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(
        find.byKey(MoviePreviewChewieControls.headerOpacityKey),
      )
      .opacity;
}

void main() {
  testWidgets('顶部栏跟随真实 Chewie 控制层自动隐藏并由单击恢复', (tester) async {
    final harness = await _pumpControls(tester, onBack: () {});

    expect(_headerOpacity(tester), 1.0);

    await tester.pump(const Duration(seconds: 3));
    expect(_headerOpacity(tester), 0.0);

    await tester.tapAt(tester.getCenter(find.byType(Chewie)));
    await tester.pump();
    expect(_headerOpacity(tester), 1.0);

    await tester.pumpWidget(const SizedBox());
    harness.chewie.dispose();
    await harness.video.dispose();
  });

  testWidgets('顶部栏隐藏时返回不可点击且不暴露语义', (tester) async {
    var backCalls = 0;
    final semantics = tester.ensureSemantics();
    final harness = await _pumpControls(tester, onBack: () => backCalls++);

    await tester.pump(const Duration(seconds: 3));
    expect(_headerOpacity(tester), 0.0);
    expect(find.bySemanticsLabel('返回'), findsNothing);

    await tester.tap(find.byTooltip('返回'), warnIfMissed: false);
    expect(backCalls, 0);

    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    harness.chewie.dispose();
    await harness.video.dispose();
  });

  test('ChewieState 缺失时顶部栏采用可见兜底', () {
    expect(moviePreviewHeaderIsHidden(null), isFalse);
  });
}
