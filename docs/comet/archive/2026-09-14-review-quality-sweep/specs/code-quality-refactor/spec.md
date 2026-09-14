# Capability: code-quality-refactor（审查修复与重构批次）

本能力描述本 change 归档后项目的安全存储、日志脱敏、图片链路、异步健壮性、架构边界与组件拆分的完整行为。

## 安全与会话存储

Scenario: 登录成功后配置存储
- GIVEN 用户完成登录
- WHEN 会话（token + 用户信息）被持久化
- THEN 内容写入 `flutter_secure_storage`，SharedPreferences 中不存在明文会话 JSON
- AND 后续应用启动从 secure storage 恢复登录态

Scenario: 旧版本明文会话迁移
- GIVEN SharedPreferences 中存在旧版本写入的明文会话 JSON
- WHEN 应用启动并读取会话
- THEN 明文会话被读取并迁移到 secure storage，旧明文数据被清除
- AND 用户登录态保持有效，不要求重新登录

Scenario: 退出登录清除
- GIVEN 使用者已登录且会话保存在 secure storage
- WHEN 用户退出登录
- THEN secure storage 中的会话被清除，界面回到未登录状态

Scenario: 敏感请求体脱敏
- GIVEN 调试日志拦截器开启
- WHEN 发出包含密码字段的请求体（如登录、修改密码）
- THEN 日志输出中该请求体以脱敏占位符显示，不出现明文密码
- AND 响应日志已有的 `[REDACTED_SECRET]` 机制保持不变

## 图片链路

Scenario: 设置更新不重建全屏图片
- GIVEN 详情页或网格页渲染多个 `CachedImage`
- WHEN SettingsProvider 通知任意字段变化
- THEN `CachedImage` 仅在自身订阅的设置值变化时重建
- AND 图片列表滚动帧率行为不低于改动前

Scenario: 模糊按场景应用
- GIVEN 列表小图或卡片缩略图渲染
- WHEN 图片加载完成
- THEN 该图不经过每张独立的 `ImageFiltered` 高斯模糊
- AND 大图场景（详情封面等）保留模糊能力，开关行为不变

Scenario: 目标尺寸解码
- GIVEN 网格或卡片中宽度 80~140 逻辑像素的图片槽位
- WHEN 网络图片加载并缓存位图
- THEN 传入 `memCacheWidth`/`memCacheHeight` 后按目标尺寸解码，不缓存全分辨率位图

Scenario: 封面解密低开销
- GIVEN 解密器处理未加密或加密图片字节
- WHEN 解密发生在主 isolate
- THEN 使用 `Uint8List` 原地处理，不再逐字节迭代生成装箱拷贝；解密结果与既有测试期望一致

## 异步健壮性

Scenario: 主题持久化失败可观测
- GIVEN 用户切换主题模式
- WHEN 持久化写入抛出异常
- THEN 异常被捕获并记录日志，UI 不崩溃，已选主题保持

Scenario: Home 分区加载失败
- GIVEN Home 页某分区发起加载
- WHEN 请求抛出异常
- THEN 异常不再成为未处理异步错误，分区错误有日志/状态记录
- AND 既有 `tofu_scroll_test`、`home_screen_test` 全部用例通过

Scenario: 静默吞异常处补日志
- GIVEN `movie_preview_screen` 等五处 `catch (_)` 静默路径
- WHEN 异常发生
- THEN 输出 debug 日志标识失败点，不影响正常用户行为

## 架构边界

Scenario: 依赖方向合规
- GIVEN 跨 feature 复用的 following_tags、collections、token 认证等能力
- WHEN 代码按归档后结构组织
- THEN 复用能力位于 `core/`（或仅经该 feature `index.dart` 导出），feature 之间无内部实现直引
- AND `lib/core/services` 不 import 任何 feature 内部实现文件
- AND `lib/main.dart` 不直接 import feature 内部细粒度文件（经 index 组装）

## 组件拆分

Scenario: 详情页区块独立
- GIVEN `movie_detail_screen` 的详情/磁链/短评/相关清单四路数据
- WHEN 任一路数据单独完成加载
- THEN 只有该区块子树重建，其他区块的列表滚动位置与展开状态不因无关区块 setState 而丢失
- AND 页面对外可见布局与交互与拆分前一致

Scenario: review_tile 行为不变
- GIVEN 拆分后的 `ReviewTile` 系列 widget 文件
- WHEN 影片详情页短评列表或"看短评"页渲染评论
- THEN 文本选择、展开/收起、点赞/回复区等交互与拆分前一致，相关既有测试通过

Scenario: 收藏/列表页样板收敛
- GIVEN `my_lists_page`、`collected_actors_page`、`common_list_page` 三个页面
- WHEN 页面加载数据并渲染
- THEN 使用公共基类或共享组件提供加载/错误/重试/列表能力，三页功能与拆分前一致

## 约定统一

Scenario: 状态类与目录约定一致
- GIVEN ChangeNotifier 型状态类与 `home/providers/home_provider.dart`
- WHEN 目录约定更新落地
- THEN feature 目录只包含约定子目录，状态类统一放入 `services/`
- AND `STRUCTURE.md` 描述与实际目录一致（包括 rankings/models、widgets 等既有漂移）

Scenario: Screen/Page 命名统一
- GIVEN 使用 Page 命名的 screen 文件（`common_list_page`、`makers_page` 等）
- WHEN 命名统一为 Screen 系
- THEN 文件与类名统一为 Screen 系，全部 import/路由引用同步更新，全库再无同类混用

## 全局质量门槛

Scenario: 静态检查与测试
- WHEN 对项目运行 `flutter analyze --no-pub`
- THEN 输出 No issues found
- WHEN 对项目运行 `flutter test`
- THEN 全部既有与新增用例通过，无 skip
