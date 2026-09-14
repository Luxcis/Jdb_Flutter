# 目标

按用户指定顺序完成九组审查修复与重构，保持全部既有用户可见行为不变（除安全与会话存储迁移），`flutter analyze --no-pub` 零告警，`flutter test` 全量通过。

# 范围

- 安全与存储：登录态（token + 用户信息）从 SharedPreferences 迁移到 `flutter_secure_storage`，兼容旧明文数据的读取迁移与清除；调试日志拦截器对含密码的请求体脱敏。
- 图片链路性能：`CachedImage` 改用 `context.select` 精确订阅 SettingsProvider；高斯模糊仅应用于大图场景、列表小图不再包 `ImageFiltered`；网络图按目标尺寸解码（`memCacheWidth` 等）；封面解密改 `Uint8List` 原地/低开销处理。
- 异步健壮性：主题持久化（`theme_provider.dart`）与 Home 分区加载（`home_screen.dart`）的异步操作补异常处理；补齐 `movie_preview_screen` 等静默吞异常处的日志。
- 架构：跨 feature 复用的 following_tags、collections、token 认证等能力上提 core 或经 index 导出，消除 `core/services` 反向依赖 feature 内部实现与 `main.dart` 穿透 import。
- 巨型组件拆分：`movie_detail_screen.dart` 按数据区块拆分子 widget，各区块独立加载状态；`review_tile.dart` 拆分为多个文件/子组件，保持文本选择等既有能力不变。
- 样板收敛：三个结构高度相似的收藏/列表页（`my_lists_page`、`collected_actors_page`、`common_list_page`）抽公共基类或复用组件。
- 约定统一：`home/providers/` 并入 features 子目录约定，ChangeNotifier 状态类统一放置并更新 `STRUCTURE.md`；Screen/Page 命名统一为 Screen 系并更新引用。

# 非目标

- 不处理 `docs/api/signature/ALGORITHM.md` 移出仓库、APK 热更新校验（schema verify）。
- 不做 cacheExtent 全局调整、`_stillThumbnailAspectMemo` LRU 化、`PaginatedListView` fetchMore 幂等改造等其他性能项。
- 不新增 settings/rankings 等模块的新测试，只保证既有测试全部通过并为本项修动补必要的回归测试。
- 不引入新的状态管理框架（维持 provider + ChangeNotifier）。

# 验收示例

- A1: 登录态（token + 用户信息）保存到 `flutter_secure_storage`；任意路径下 SharedPreferences 中不再出现明文会话 JSON。
- A2: 旧版本升级场景下，已存在的明文会话能被正确读取迁移并从 SharedPreferences 清除，用户登录态不丢失。
- A3: 退出登录后 secure storage 中会话被清除，功能行为与现状一致。
- A4: 登录/改密等含密码字段的 POST 请求体在调试日志中不再原样输出（以脱敏占位替代），其他日志能力不回退。
- A5: `CachedImage` 仅通过 `select` 订阅其需要的单个设置值；SettingsProvider 任意字段变化不再触发全屏图片 widget 重建。
- A6: 列表小图与卡片缩略图不再经过每张独立的高斯模糊 `ImageFiltered`；大图场景的模糊失效开关行为保留。
- A7: 网格/卡片小槽位图片解码后缓存的位图尺寸与槽位匹配（传入 memCacheWidth/memCacheHeight），不再是原图全尺寸。
- A8: 封面图片解密不再逐字节生成装箱的 `List<int>` 双份拷贝，大图解密在主 isolate 的开销明显降低（或移出主 isolate）。
- A9: 主题切换与 Home 分区加载的异步失败不再产生未处理异常，且失败有日志可查。
- A10: `movie_preview_screen` 等处静默 `catch (_)` 不再完全无痕迹，关键路径有 debugPrint/日志。
- A11: `core` 不再 import feature 内部实现文件；跨 feature 复用只经 `index.dart` 导出或 core 公共模块；`main.dart` 不再直接 import feature 内部细粒度文件。
- A12: 详情页各数据区块（详情/磁链/短评/相关清单）各自维护加载状态，单区块加载完成不再整页重建全部区块；任意 Tab 的滚动与展开行为不变。
- A13: `review_tile.dart` 拆分后既有能力不变：短评列表与"看短评"页的文本选择、展开/收起、点赞等交互行为与拆分前一致。
- A14: 三个收藏/列表页抽公共基类（或复用组件）后，各页面加载/错误/重试/列表功能不变，显著减少重复样板。
- A15: `home/providers/` 目录不再存在，状态类统一放在约定目录；`STRUCTURE.md` 与实际目录一致。
- A16: Screen/Page 命名统一（以 Screen 系为准），改名的文件全部更名并同步全部引用，无遗留混合命名。
- A17: `flutter analyze --no-pub` 零告警；`flutter test` 全量通过；若新增回归测试则修复前可复现问题、修复后通过。

# 约束与不变量

- 依赖管理：不新增依赖包（`flutter_secure_storage` 已在依赖中）；本机 pub get 会重写 lock 文件，一律避免触发。
- 娱乐功能与界面交互不变：所有列表、详情、筛选、主题、登录流程的用户可见行为保持（除 A2/A3 规定的存储迁移）。
- 剧照缩略图宽高比记忆与回滑稳定（既有已归档能力）不得回退。
- 既有测试套件全部通过；禁止 skip 测试。
- Android 构建配置、签名、manifest 权限不改动。

# 决策

- 存储迁移采用"首启读取旧明文 → 写入 secure storage → 删除旧 keys"的一次性迁移策略，保持 `AuthProvider` 对外接口不变。
- 高斯模糊改为显式按场景开启（大图/详情封面），`CachedImage` 保持默认不模糊，避免误伤列表性能。
- Screen/Page 命名统一以 Screen 为准（与多数文件现状一致）。
- 状态类统一放入 `services/`（放弃恢复 `providers/` 目录），并同步 `STRUCTURE.md` 文案。
- 跨 feature 复用能力的归属：following_tags、collections、token 认证上提 `core/`；simple 复用（仅一两处）经 `index.dart` 导出。

# 待解决问题

（无阻塞项）

# 验证预期

- `flutter analyze --no-pub`：No issues found。
- `flutter test`：全量用例通过（含既有 894+ 用例）。
- A1/A2/A3 通过新增 auth_provider 回归测试验证（secure storage fake 模拟）。
- A5/A8 通过实现审查验证；A4 通过拦截器单测验证请求体脱敏。
- 架构项 A11/A15/A16 通过 grep 断言（无违例 import、无残留目录/命名）验证。
