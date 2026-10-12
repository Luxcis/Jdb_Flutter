# 目标

重构预告片播放页（MoviePreviewScreen）的设备全局操作层，将方向锁定、屏幕常亮、系统栏沉浸三种协调器的公共 lease/串行队列/所有权逻辑抽象为可复用的通用基础类，并引入统一的 `MoviePreviewOperationManager` 来管理三种设备状态的生命周期。保持 `MoviePreviewPlayback` 播放适配器独立，不引入新的用户可见行为。

# 范围

- `lib/features/movie_detail/services/movie_preview_orientation.dart`：方向锁定协调器。
- `lib/features/movie_detail/services/movie_preview_wakelock.dart`：屏幕常亮协调器。
- `lib/features/movie_detail/services/movie_preview_system_ui.dart`：系统栏沉浸协调器。
- 新增通用 lease 协调器抽象，统一 `_pendingOperation` 串行队列、所有权校验与 lease 生命周期。
- 新增 `MoviePreviewOperationManager`，封装上述三种设备操作的一次性 `acquire`/`release` 契约。
- 更新 `lib/features/movie_detail/screens/movie_preview_screen.dart`，使其通过 OperationManager 管理设备全局状态。
- 更新并补充单元/组件测试，覆盖通用协调器与 OperationManager。

# 非目标

- 不修改 `MoviePreviewPlayback` 播放适配器及其 media_kit 实现。
- 不修改预告片视频源、路由配置、详情页入口 UI。
- 不新增用户可见的播放功能或交互。
- 不涉及主题、本地化、权限、缓存、下载等业务。

# 验收示例

- **A1**. 存在一个通用 `LeaseCoordinator`（或等效抽象），能够承载方向、wakelock、系统栏三种协调器的串行执行、lease 所有权与迟到释放防护逻辑。
- **A2**. `MoviePreviewOperationManager` 提供单一 `acquire()` / `release()` 接口，内部同时管理横屏锁定、屏幕常亮、沉浸模式三种设备状态；Screen 不再分别持有三个 lease。
- **A3**. 重构后 `MoviePreviewScreen` 仍满足现有行为：进入页面时先锁横屏，成功后初始化和播放，播放期间保持 wakelock，页面打开即进入沉浸模式，退出时恢复方向与系统栏。
- **A4**. 重叠页面场景下，旧页面的迟到 `release()` 不会覆盖新页面已经获取的设备状态。
- **A5**. 方向锁定、系统栏设置或 wakelock 中任意一项失败时，不影响其他项的清理与恢复流程；页面仍可在退出后恢复系统默认状态。
- **A6**. 现有 `test/features/movie_detail/movie_preview_*` 测试全部通过，并新增对通用 lease 协调器与 OperationManager 的单元测试。
- **A7**. `dart analyze` 无错误，`dart format` 无需额外修改。

# 约束与不变量

- **串行执行**：同一协调器上的进入/退出操作必须按 FIFO 顺序执行，避免交叉设置导致状态错乱。
- **所有权隔离**：lease 被新 `acquire` 取代后，旧 lease 的 `release()` 不得触发实际恢复操作。
- **幂等释放**：单个 lease 的 `release()` 多次调用只执行一次实际恢复。
- **失败隔离**：某一项设备操作失败不得阻塞其他设备状态的恢复；清理路径仍应尽力执行。
- **构造兼容**：尽量保持现有测试注入方式可用，或通过 thin wrapper 提供兼容 API，避免大规模修改既有测试。

# 决策

- 使用泛型 `LeaseCoordinator<TLease>`（或等价设计）作为三个协调器的共同基类，将队列与所有权逻辑集中到一处。
- `MoviePreviewOperationManager` 在 `MoviePreviewScreen.initState()` 中 `acquire`，在 `dispose()` 中 `release`；播放会话的初始化和清理仍由 Screen 负责。
- 原有三个协调器类保留为 public API，内部改为基于通用 lease 协调器的薄封装，避免破坏既有调用方和测试。

# 待解决问题

- 无

# 验证预期

- `dart analyze` 通过，无新 lint 错误。
- 全部 `test/features/movie_detail/movie_preview_*` 测试通过。
- 新增 `test/features/movie_detail/movie_preview_operation_manager_test.dart` 与 `test/features/movie_detail/movie_preview_lease_test.dart`（或等价文件），覆盖通用 lease 协调器与 OperationManager 的核心场景。
- 不引入运行时行为回归：通过对比 Screen 测试的现有断言确认进入/退出序列一致。
