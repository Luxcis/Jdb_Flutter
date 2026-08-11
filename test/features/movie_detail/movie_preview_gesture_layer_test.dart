import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_gesture_layer.dart';

void main() {
  testWidgets('单击透传给子树且外层不切换播放', (tester) async {
    var childTapCalls = 0;
    var toggleCalls = 0;
    await tester.pumpWidget(
      _buildLayer(
        child: GestureDetector(
          onTap: () => childTapCalls++,
          child: const ColoredBox(color: Colors.black),
        ),
        onTogglePlayback: () async => toggleCalls++,
      ),
    );

    await tester.tapAt(_surfacePoint(tester));
    await tester.pump(kDoubleTapTimeout);

    expect(childTapCalls, 1);
    expect(toggleCalls, 0);
  });

  testWidgets('双击只调用一次播放切换', (tester) async {
    var toggleCalls = 0;
    await tester.pumpWidget(
      _buildLayer(onTogglePlayback: () async => toggleCalls++),
    );

    final point = _surfacePoint(tester);
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(point);
    await tester.pump();

    expect(toggleCalls, 1);
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('长按成功显示 2.0× 且松手恢复 1.0×', (tester) async {
    final speeds = <double>[];
    await tester.pumpWidget(
      _buildLayer(onSetPlaybackSpeed: (speed) async => speeds.add(speed)),
    );

    final gesture = await tester.startGesture(_surfacePoint(tester));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(speeds, [2.0]);
    expect(find.text('2.0×'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(speeds, [2.0, 1.0]);
    expect(find.text('2.0×'), findsNothing);
  });

  testWidgets('长按取消只恢复一次 1.0×', (tester) async {
    final speeds = <double>[];
    await tester.pumpWidget(
      _buildLayer(onSetPlaybackSpeed: (speed) async => speeds.add(speed)),
    );

    final gesture = await tester.startGesture(_surfacePoint(tester));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.cancel();
    await tester.pump();

    expect(speeds, [2.0, 1.0]);
  });

  testWidgets('2.0× 延迟时提前松手最终串行恢复 1.0×', (tester) async {
    final allowDoubleSpeed = Completer<void>();
    final speeds = <double>[];
    var appliedSpeed = 1.0;
    await tester.pumpWidget(
      _buildLayer(
        onSetPlaybackSpeed: (speed) async {
          speeds.add(speed);
          if (speed == 2.0) {
            await allowDoubleSpeed.future;
          }
          appliedSpeed = speed;
        },
      ),
    );

    final gesture = await tester.startGesture(_surfacePoint(tester));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.up();
    allowDoubleSpeed.complete();
    await tester.pump();
    await tester.pump();

    expect(speeds, [2.0, 1.0]);
    expect(appliedSpeed, 1.0);
    expect(find.text('2.0×'), findsNothing);
  });

  testWidgets('设置 2.0× 失败不显示提示且不进入恢复错误', (tester) async {
    var recoveryFailureCalls = 0;
    await tester.pumpWidget(
      _buildLayer(
        onSetPlaybackSpeed: (speed) async {
          if (speed == 2.0) throw StateError('set 2x failed');
        },
        onSpeedRecoveryFailure: () async => recoveryFailureCalls++,
      ),
    );

    final gesture = await tester.startGesture(_surfacePoint(tester));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('2.0×'), findsNothing);
    await gesture.up();
    await tester.pump();

    expect(recoveryFailureCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('恢复 1.0× 失败通知页面一次并隐藏错误倍速提示', (tester) async {
    var recoveryFailureCalls = 0;
    await tester.pumpWidget(
      _buildLayer(
        onSetPlaybackSpeed: (speed) async {
          if (speed == 1.0) throw StateError('restore failed');
        },
        onSpeedRecoveryFailure: () async => recoveryFailureCalls++,
      ),
    );

    final gesture = await tester.startGesture(_surfacePoint(tester));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();
    await tester.pump();

    expect(recoveryFailureCalls, 1);
    expect(find.text('2.0×'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('长按中销毁且恢复失败不产生异步异常', (tester) async {
    final speeds = <double>[];
    await tester.pumpWidget(
      _buildLayer(
        onSetPlaybackSpeed: (speed) async {
          speeds.add(speed);
          if (speed == 1.0) throw StateError('dispose restore failed');
        },
      ),
    );

    await tester.startGesture(_surfacePoint(tester));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(speeds, [2.0, 1.0]);
    expect(tester.takeException(), isNull);
  });
}

Widget _buildLayer({
  Widget child = const ColoredBox(color: Colors.black),
  Future<void> Function()? onTogglePlayback,
  Future<void> Function(double speed)? onSetPlaybackSpeed,
  Future<void> Function()? onSpeedRecoveryFailure,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MoviePreviewGestureLayer(
        onTogglePlayback: onTogglePlayback ?? () async {},
        onSetPlaybackSpeed: onSetPlaybackSpeed ?? (_) async {},
        onSpeedRecoveryFailure: onSpeedRecoveryFailure ?? () async {},
        child: child,
      ),
    ),
  );
}

Offset _surfacePoint(WidgetTester tester) {
  return tester.getCenter(
    find.byKey(const Key('movie-preview-gesture-surface')),
  );
}
