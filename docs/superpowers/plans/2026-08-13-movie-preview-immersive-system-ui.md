# 影片预告片播放页沉浸式系统栏实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 进入影片预告片播放页时设置 `SystemUiMode.immersiveSticky` 隐藏系统栏，退出时恢复默认双栏，并通过 lease 协调器防重叠页面竞态。

**Architecture:** 新增 `MoviePreviewSystemUiCoordinator`，完整镜像现有 `MoviePreviewOrientationCoordinator` 的 lease + 串行队列模式；页面在 `initState` 与横屏 lease 同时 acquire，`dispose` 独立释放。

**Tech Stack:** Flutter `SystemChrome.setEnabledSystemUIMode`，无新依赖。

## Global Constraints

- 目录：所有改动在 `lib/features/movie_detail/` 内；不新增 feature 目录；不改 `lib/core/`。
- 进入模式精确值：`SystemUiMode.immersiveSticky`；退出模式精确值：`SystemUiMode.manual` + `overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]`。
- 装饰性失败语义：系统 UI 设置失败吞掉并继续，不阻塞播放、不进错误页。
- 横屏锁定失败时页面保持沉浸，只有页面退出（dispose）才恢复系统栏。
- 重试不重新 acquire 系统 UI lease。
- 竞态契约：旧 lease 的迟到释放不得恢复新页面已设置的沉浸模式（串行队列 + owner 检查，同横屏协调器）。
- 文案：中文注释与 dartdoc；无本地化改动。
- 测试命令顺序：聚焦测试 → `flutter analyze` → 全量 `flutter test`；`/opt/homebrew/share/flutter` 下缓存写入失败属于环境问题，不算代码失败。
- 提交信息前缀 `feat:`；只 stage 任务文件；不推送。

---

## 文件结构

- 新增 `lib/features/movie_detail/services/movie_preview_system_ui.dart`：协调器与 lease（Task 1）。
- 新增 `test/features/movie_detail/movie_preview_system_ui_test.dart`：协调器单测（Task 1）。
- 修改 `lib/features/movie_detail/screens/movie_preview_screen.dart`：注入参数与 acquire/release 接线（Task 2）。
- 修改 `test/features/movie_detail/movie_preview_screen_test.dart`：注入 fake 协调器并新增 3 个对应用例（Task 2）。

---

### Task 1: 系统 UI 协调器

**Files:**
- Create: `lib/features/movie_detail/services/movie_preview_system_ui.dart`
- Test: `test/features/movie_detail/movie_preview_system_ui_test.dart`

**Interfaces:**
- Produces: `typedef MoviePreviewSystemUiModeSetter = Future<void> Function(SystemUiMode mode, {List<SystemUiOverlay>? overlays});`；`MoviePreviewSystemUiCoordinator({required MoviePreviewSystemUiModeSetter setSystemUiMode})`，含 `static final system`（接 `SystemChrome.setEnabledSystemUIMode`）、`acquire()` 返回 `MoviePreviewSystemUiLease`；lease 暴露 `Future<void> get enabled` 与 `Future<void> release()`。

- [ ] **Step 1: 写失败测试**

新建 `test/features/movie_detail/movie_preview_system_ui_test.dart`：

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_system_ui.dart';

class _RecordingSetter {
  final calls = <({SystemUiMode mode, List<SystemUiOverlay>? overlays})>[];

  Future<void> call(
    SystemUiMode mode, {
    List<SystemUiOverlay>? overlays,
  }) async {
    calls.add((mode: mode, overlays: overlays));
  }
}

void main() {
  test('acquire 设置沉浸模式', () async {
    final setter = _RecordingSetter();
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: setter.call,
    );

    final lease = coordinator.acquire();
    await lease.enabled;

    expect(
      setter.calls,
      [(mode: SystemUiMode.immersiveSticky, overlays: null)],
    );
    await lease.release();
  });

  test('release 恢复默认双栏', () async {
    final setter = _RecordingSetter();
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: setter.call,
    );

    final lease = coordinator.acquire();
    await lease.enabled;
    await lease.release();

    expect(setter.calls.last.mode, SystemUiMode.manual);
    expect(
      setter.calls.last.overlays,
      [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  });

  test('旧 lease 被取代后，其迟到释放不触发恢复', () async {
    final setter = _RecordingSetter();
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: setter.call,
    );

    final first = coordinator.acquire();
    await first.enabled;
    final second = coordinator.acquire();
    await second.enabled;

    await first.release();
    expect(setter.calls.length, 2);

    await second.release();
    expect(setter.calls.length, 3);
    expect(setter.calls.last.mode, SystemUiMode.manual);
  });

  test('release 在 acquire 完成前排队，顺序为进入后退出', () async {
    final setter = _RecordingSetter();
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: setter.call,
    );

    final lease = coordinator.acquire();
    await lease.release();

    expect(setter.calls.first.mode, SystemUiMode.immersiveSticky);
    expect(setter.calls.last.mode, SystemUiMode.manual);
  });

  test('acquire 失败后 release 仍执行恢复', () async {
    var failEnter = true;
    final setter = _RecordingSetter();
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: (mode, {overlays}) async {
        if (failEnter && mode == SystemUiMode.immersiveSticky) {
          throw StateError('set failed');
        }
        await setter.call(mode, overlays: overlays);
      },
    );

    final lease = coordinator.acquire();
    await expectLater(lease.enabled, throwsA(isA<StateError>()));

    failEnter = false;
    await lease.release();

    expect(setter.calls.single.mode, SystemUiMode.manual);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/movie_detail/movie_preview_system_ui_test.dart`

Expected: FAIL，报 `movie_preview_system_ui.dart` 找不到。

- [ ] **Step 3: 实现协调器**

新建 `lib/features/movie_detail/services/movie_preview_system_ui.dart`：

```dart
import 'dart:async';

import 'package:flutter/services.dart';

typedef MoviePreviewSystemUiModeSetter = Future<void> Function(
  SystemUiMode mode, {
  List<SystemUiOverlay>? overlays,
});

/// 协调预告片页面沉浸式系统栏的所有权，防止重叠页面之间的迟到恢复竞态。
///
/// 与 [MoviePreviewOrientationCoordinator] 同构：acquire 返回 lease，
/// 内部串行队列保证调用顺序；旧 lease 被取代后其释放不再生效。
class MoviePreviewSystemUiCoordinator {
  MoviePreviewSystemUiCoordinator({
    required MoviePreviewSystemUiModeSetter setSystemUiMode,
  }) : _setSystemUiMode = setSystemUiMode;

  static final system = MoviePreviewSystemUiCoordinator(
    setSystemUiMode: SystemChrome.setEnabledSystemUIMode,
  );

  static const enterMode = SystemUiMode.immersiveSticky;
  static const exitMode = SystemUiMode.manual;
  static const exitOverlays = [
    SystemUiOverlay.top,
    SystemUiOverlay.bottom,
  ];

  final MoviePreviewSystemUiModeSetter _setSystemUiMode;
  Future<void> _pendingOperation = Future<void>.value();
  MoviePreviewSystemUiLease? _owner;

  MoviePreviewSystemUiLease acquire() {
    final lease = MoviePreviewSystemUiLease._(this);
    _owner = lease;
    lease._enabled = _enqueue(() async {
      _ensureOwner(lease);
      await _setSystemUiMode(enterMode);
      _ensureOwner(lease);
    });
    return lease;
  }

  Future<void> _release(MoviePreviewSystemUiLease lease) {
    if (!identical(_owner, lease)) {
      return Future<void>.value();
    }
    _owner = null;
    return _enqueue(() async {
      if (_owner != null) return;
      await _setSystemUiMode(exitMode, overlays: exitOverlays);
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pendingOperation.then((_) => operation());
    _pendingOperation = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void _ensureOwner(MoviePreviewSystemUiLease lease) {
    if (!identical(_owner, lease)) {
      throw StateError('Movie preview system UI lease was superseded');
    }
  }
}

class MoviePreviewSystemUiLease {
  MoviePreviewSystemUiLease._(this._coordinator);

  final MoviePreviewSystemUiCoordinator _coordinator;
  late final Future<void> _enabled;
  Future<void>? _release;

  Future<void> get enabled => _enabled;

  Future<void> release() => _release ??= _coordinator._release(this);
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/movie_detail/movie_preview_system_ui_test.dart`

Expected: PASS（5 个用例）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/movie_detail/services/movie_preview_system_ui.dart test/features/movie_detail/movie_preview_system_ui_test.dart
git commit -m "feat: add immersive system ui coordinator for movie preview"
```

---

### Task 2: 页面接线

**Files:**
- Modify: `lib/features/movie_detail/screens/movie_preview_screen.dart`
- Modify: `test/features/movie_detail/movie_preview_screen_test.dart`

**Interfaces:**
- Consumes: `MoviePreviewSystemUiCoordinator` / `MoviePreviewSystemUiLease`（Task 1）。
- Produces: `MoviePreviewPage` 新增可选参数 `systemUiCoordinator`（默认 `MoviePreviewSystemUiCoordinator.system`）。

- [ ] **Step 1: 写失败测试（红）**

修改 `test/features/movie_detail/movie_preview_screen_test.dart`：

1a. 在文件顶部 import 区新增：

```dart
import 'package:jade/features/movie_detail/services/movie_preview_system_ui.dart';
```

1b. 在 `const _validArgs = ...` 附近新增共享 no-op 协调器：

```dart
final _testSystemUiCoordinator = MoviePreviewSystemUiCoordinator(
  setSystemUiMode: (mode, {overlays}) async {},
);
```

1c. 给测试文件中全部 12 处 `MoviePreviewPage(` 构造添加 `systemUiCoordinator: _testSystemUiCoordinator`（其中 1 处在 `_pumpPreviewPage` 内，其余为直接构造；每个构造的命名参数块内任选一行后追加即可）。

1d. 在文件末尾（`_FakePlayback` 类之后）新增 3 个用例：

```dart
  testWidgets('进入页面设置沉浸模式，退出恢复默认双栏', (tester) async {
    final calls = <({SystemUiMode mode, List<SystemUiOverlay>? overlays})>[];
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: (mode, {overlays}) async {
        calls.add((mode: mode, overlays: overlays));
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MoviePreviewPage(
          args: _validArgs,
          playbackFactory: (_) => _FakePlayback(),
          orientationSetter: (_) async {},
          systemUiCoordinator: coordinator,
        ),
      ),
    );
    await tester.pump();

    expect(
      calls.first,
      (mode: SystemUiMode.immersiveSticky, overlays: null),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(calls.last.mode, SystemUiMode.manual);
    expect(
      calls.last.overlays,
      [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('横屏锁定失败时仍保持沉浸，退出时恢复', (tester) async {
    final calls = <SystemUiMode>[];
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: (mode, {overlays}) async {
        calls.add(mode);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MoviePreviewPage(
          args: _validArgs,
          playbackFactory: (_) => _FakePlayback(),
          orientationSetter: (_) async {
            throw StateError('orientation lock failed');
          },
          systemUiCoordinator: coordinator,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('预告片播放失败'), findsOneWidget);
    expect(calls, [SystemUiMode.immersiveSticky]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(calls.last, SystemUiMode.manual);
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧页面迟到恢复不会破坏新页面的沉浸模式', (tester) async {
    final releaseGate = Completer<void>();
    final calls = <SystemUiMode>[];
    final coordinator = MoviePreviewSystemUiCoordinator(
      setSystemUiMode: (mode, {overlays}) async {
        calls.add(mode);
        if (mode == SystemUiMode.manual && calls.where((m) => m == SystemUiMode.manual).length == 1) {
          await releaseGate.future;
        }
      },
    );

    Widget buildPage() {
      return MaterialApp(
        home: MoviePreviewPage(
          args: _validArgs,
          playbackFactory: (_) => _FakePlayback(),
          orientationSetter: (_) async {},
          systemUiCoordinator: coordinator,
        ),
      );
    }

    await tester.pumpWidget(buildPage());
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    await tester.pumpWidget(buildPage());
    await tester.pump();

    releaseGate.complete();
    await tester.pump();

    expect(calls.last, SystemUiMode.immersiveSticky);
    expect(tester.takeException(), isNull);
  });
```

注意：1c 与 1d 引用尚不存在的 `systemUiCoordinator` 参数，编译失败即红态。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/movie_detail/movie_preview_screen_test.dart`

Expected: FAIL，报 `MoviePreviewPage` 不存在 `systemUiCoordinator` 命名参数（编译错误）。

- [ ] **Step 3: 实现页面接线**

修改 `lib/features/movie_detail/screens/movie_preview_screen.dart`：

3a. import 区新增：

```dart
import 'package:jade/features/movie_detail/services/movie_preview_system_ui.dart';
```

3b. Widget 构造与字段：

```dart
  const MoviePreviewPage({
    super.key,
    required this.args,
    this.playbackFactory,
    this.orientationSetter,
    this.orientationCoordinator,
    this.wakelockCoordinator,
    this.systemUiCoordinator,
  }) : ...

  final MoviePreviewSystemUiCoordinator? systemUiCoordinator;
```

3c. State 字段与初始化：

```dart
  late final MoviePreviewSystemUiCoordinator _systemUiCoordinator;
  MoviePreviewSystemUiLease? _systemUiLease;
```

`initState()` 中，在 `final generation = ++_lifecycleGeneration;` 之前追加：

```dart
    _systemUiCoordinator =
        widget.systemUiCoordinator ?? MoviePreviewSystemUiCoordinator.system;
    final systemUiLease = _systemUiCoordinator.acquire();
    _systemUiLease = systemUiLease;
    unawaited(_ignoreSystemUiOperation(systemUiLease.enabled));
```

3d. `dispose()` 中，在 `unawaited(_releaseWakelock(wakelockLease));` 之后追加：

```dart
    final systemUiLease = _systemUiLease;
    _systemUiLease = null;
    unawaited(_releaseSystemUi(systemUiLease));
```

3e. 新增两个私有方法（放在 `_releaseWakelock` 附近）：

```dart
  Future<void> _releaseSystemUi(MoviePreviewSystemUiLease? lease) async {
    if (lease == null) return;
    await _ignoreSystemUiOperation(lease.release());
  }

  Future<void> _ignoreSystemUiOperation(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {}
  }
```

3f. `_retry()` 不新增任何 acquire 调用（页面已处于沉浸状态，lease 在 retry 期间保持持有）。

- [ ] **Step 4: 运行聚焦测试确认通过**

Run:

```bash
flutter test test/features/movie_detail/movie_preview_system_ui_test.dart test/features/movie_detail/movie_preview_screen_test.dart
```

Expected: 全部 PASS（协调器 5 例 + 页面测试原有与新增 3 例）。

- [ ] **Step 5: 静态分析与全量测试**

Run: `flutter analyze`

Expected: 0 issues。

Run: `flutter test`

Expected: 全部 PASS（611 + 新增）。

- [ ] **Step 6: Commit**

```bash
git add lib/features/movie_detail/screens/movie_preview_screen.dart test/features/movie_detail/movie_preview_screen_test.dart
git commit -m "feat: hide system bars on movie preview"
```

---

## 验证清单（提交后人工确认）

在真机/模拟器上确认：

- 进入预告片播放页后状态栏与导航栏立即隐藏；
- 从屏幕边缘滑入可临时唤出系统栏，数秒后自动再隐藏；
- 返回影片详情页后系统栏恢复显示；
- 横屏锁定失败的错误页同样处于沉浸状态，可正常返回。
