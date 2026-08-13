import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/widgets/movie_preview_double_tap_detector.dart';

class _FakeClock {
  DateTime current = DateTime(2026, 8, 13, 12, 0, 0);
  DateTime call() => current;
}

Widget _wrap({
  required _FakeClock clock,
  required VoidCallback onDoubleTap,
  required Widget child,
}) {
  return MaterialApp(
    home: MoviePreviewDoubleTapDetector(
      clock: clock.call,
      onDoubleTap: onDoubleTap,
      child: child,
    ),
  );
}

void main() {
  testWidgets('间隔不超过 300ms 且位置接近的两次按下触发一次回调', (tester) async {
    final clock = _FakeClock();
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        clock: clock,
        onDoubleTap: () => calls++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 200));
    await tester.tapAt(const Offset(105, 102));

    expect(calls, 1);
  });

  testWidgets('两次按下超过 300ms 不触发', (tester) async {
    final clock = _FakeClock();
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        clock: clock,
        onDoubleTap: () => calls++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 301));
    await tester.tapAt(const Offset(100, 100));

    expect(calls, 0);
  });

  testWidgets('两次按下位置差超过 100 不触发', (tester) async {
    final clock = _FakeClock();
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        clock: clock,
        onDoubleTap: () => calls++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(250, 100));

    expect(calls, 0);
  });

  testWidgets('第二指针按下时清除历史，之后单击不再误判', (tester) async {
    final clock = _FakeClock();
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        clock: clock,
        onDoubleTap: () => calls++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 301));

    final first = await tester.startGesture(const Offset(100, 100));
    final second = await tester.startGesture(const Offset(300, 300));
    await first.up();
    await second.up();
    await tester.pump();

    await tester.tapAt(const Offset(100, 100));

    expect(calls, 0);
  });

  testWidgets('触发后历史复位，随后的双击再次触发', (tester) async {
    final clock = _FakeClock();
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        clock: clock,
        onDoubleTap: () => calls++,
        child: const SizedBox.expand(),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(100, 100));
    expect(calls, 1);

    clock.current = clock.current.add(const Duration(milliseconds: 500));
    await tester.tapAt(const Offset(100, 100));
    clock.current = clock.current.add(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(100, 100));

    expect(calls, 2);
  });
}
