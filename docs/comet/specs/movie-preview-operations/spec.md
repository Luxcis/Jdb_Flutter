# 预告片播放操作层规格

## 概述

预告片播放页在播放期间需要同时控制三项设备全局状态：

1. **方向锁定**：强制横屏（`landscapeLeft` / `landscapeRight`）。
2. **屏幕常亮**：播放期间保持屏幕唤醒。
3. **系统栏沉浸**：隐藏状态栏和导航栏，使用 `immersiveSticky` 模式。

本规格定义这些设备状态的操作层抽象、生命周期与并发安全约束。

## 通用 Lease 协调器

### LeaseCoordinator

`LeaseCoordinator<TLease>` 是一个通用协调器，负责管理同类设备状态的所有权与串行操作队列。

#### 职责

- 维护一个串行操作队列 `_pendingOperation`，保证进入/退出操作按 FIFO 顺序执行。
- 跟踪当前有效的 lease（`_owner` 或 `_owners`）。
- 提供 `acquire()` 方法创建新 lease，并将其设为当前所有者。
- 在 lease 过期（被新 `acquire` 取代）后，其 `release()` 为无操作。
- 单个 lease 的 `release()` 幂等：多次调用只执行一次实际恢复。

#### 行为

- `acquire()` 时立即将新 lease 设为当前所有者，并把进入操作加入队列。
- `release()` 时先校验 lease 是否仍为当前所有者；若不是，立即返回无操作。
- 进入/退出操作在队列中串行执行，后一个操作必须等前一个完成后才开始。
- 操作失败时，队列继续处理后续操作，不阻塞整体流程。

### Lease

每个 lease 代表一次设备状态所有权。

- `enabled` / `locked`：`Future`，进入操作完成时完成（可能以错误完成）。
- `release()`：幂等地归还所有权并触发恢复操作。

## 设备状态协调器

三种设备状态协调器均基于通用 `LeaseCoordinator` 实现，仅定义各自的进入/退出操作。

### MoviePreviewOrientationCoordinator

- **进入操作**：调用 `setPreferredOrientations([landscapeLeft, landscapeRight])`。
- **退出操作**：调用 `setPreferredOrientations([])`。
- 使用单所有者模型：新 `acquire` 取代旧 lease，旧 lease 的恢复操作不再执行。

### MoviePreviewSystemUiCoordinator

- **进入操作**：调用 `setEnabledSystemUIMode(immersiveSticky)`。
- **退出操作**：调用 `setEnabledSystemUIMode(manual, overlays: [top, bottom])`。
- 使用单所有者模型，与方向协调器一致。

### MoviePreviewWakelockCoordinator

- **进入操作**：调用 `setWakelockEnabled(true)`。
- **退出操作**：调用 `setWakelockEnabled(false)`。
- 使用多所有者模型：只要还有一个有效 lease，wakelock 就保持启用；最后一个 lease 释放后才禁用。

## MoviePreviewOperationManager

`MoviePreviewOperationManager` 是 `MoviePreviewScreen` 与三项设备状态协调器之间的统一门面。

### 职责

- 在页面打开时一次性 `acquire()` 方向、wakelock、系统栏三种 lease。
- 在页面关闭时一次性 `release()` 所有 lease。
- 向上层暴露单一的生命周期契约，隐藏三个协调器的差异。

### 行为

- `acquire()` 同时获取三种 lease，返回一个 `MoviePreviewOperationLease`（或等价对象）。
- `release()` 幂等地释放所有 lease，并忽略任何单个子操作的失败。
- 方向锁定的 `locked` future 需要被 Screen 等待，作为初始化播放的前置条件。
- wakelock 与系统栏 lease 的 `enabled` future 由 OperationManager 内部处理，失败仅记录日志，不阻塞播放。

## MoviePreviewScreen 集成

### 进入流程

1. `initState()` 中创建或接收 `MoviePreviewOperationManager`。
2. 调用 `operationManager.acquire()`。
3. 等待方向 lease 的 `locked` future。
4. 方向锁定成功后，创建并初始化 `MoviePreviewPlayback`，成功后调用 `play()`。
5. 系统栏与 wakelock 的进入操作可与方向锁定并行或在 OperationManager 内部完成。

### 退出流程

1. `dispose()` 中调用 `operationManager.release()`。
2. 同时释放播放会话、方向、wakelock、系统栏资源。
3. 各项清理操作相互独立，一项失败不影响其他项。

### 错误处理

- 方向锁定失败：显示“预告片播放失败”错误页，并尝试恢复系统默认状态。
- 系统栏或 wakelock 失败：不影响播放，退出时仍尝试恢复。
- 播放初始化失败：显示错误页，并释放已获取的设备状态 lease。

## 并发安全

### 重叠页面

当两个 `MoviePreviewScreen` 实例同时存在（例如导航动画期间）：

- 每个页面拥有自己的 OperationManager lease。
- 新页面的 `acquire` 取代旧页面的方向/系统栏所有权。
- 旧页面的迟到 `release()` 不会覆盖新页面已经设置的状态。
- wakelock 多所有者模型保证只要任一页面存在，屏幕就保持唤醒。

### 快速进出

- 页面在 `acquire` 完成前被释放时，退出操作在队列中排在进入操作之后，确保“先进入、后退出”。
- 即使进入操作失败，退出操作仍会尝试恢复默认状态。

## 测试要求

- 通用 `LeaseCoordinator` 的单元测试覆盖：串行队列、所有权取代、幂等释放、失败隔离。
- `MoviePreviewOperationManager` 的单元测试覆盖：同时获取/释放三种 lease、失败隔离、重叠页面安全。
- `MoviePreviewScreen` 的现有 widget 测试继续通过，验证进入/退出序列不变。
