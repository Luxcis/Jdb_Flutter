# Capability: review-findings-remediation（审查报告 P0+P1 修复批次）

本能力描述本 change 归档后项目在启动与线路自愈、本地数据容错、认证会话、播放器、列表与榜单、错误文案、无障碍、架构边界与测试基线方面的完整行为。范围限定为 `docs/reports/review-report.md` 的 37 条 P0+P1 发现，其余能力保持既有规格不变。

## 启动与线路自愈

### Scenario: 启动线路自愈
- GIVEN 应用冷启动，需要请求 startup 接口
- WHEN 组装启动请求的目标地址
- THEN 按「DomainManager 持久化的可用线路（key_baseurl/apiDomains）→ 备用域名（backupUrls/permanentAppDomain/unblockAppDomain 中可解析的 https 地址）→ 兜底域名 fallbackBaseUrl」的顺序去重后依次尝试
- AND 某候选不可达（连接错误/超时/608）时自动改用下一候选，而不是重复请求同一地址
- AND 本地存在可用线路时，即使兜底域名不可达也能成功完成启动并进入主页
- AND 全部候选失败时仍显示启动失败页，用户点「重试」会重新遍历候选（从持久化线路开始），并区分可重试（网络/超时）与不可重试（解码/配置）错误
- AND 启动成功返回的新域名列表在通过下述校验后才会持久化
验收：A1

### Scenario: 请求级线路轮转
- GIVEN ApiClient 已装配域名轮转拦截器
- WHEN 单个请求因 608 或连接错误失败
- THEN 该请求最多自动重试 1 次，重试标记只作用于该请求（`RequestOptions.extra`），请求结束后不再保留
- AND 同一进程生命周期内，后续新的失败请求仍可再次触发轮转，不因历史轮转被永久禁止
- AND 多个请求并发失败时，`rotate()` 串行执行且只切换一次线路；域名列表为 2 个时不会双跳回原失效域名
- AND 轮转重试失败时保留原始错误类型与响应信息，不丢失 `response`、不把原始错误吞掉
验收：A2

### Scenario: 下发域名校验
- GIVEN startup 响应返回 `apiDomains`（由 AES 解密得到）或用户在设置中选择线路
- WHEN 应用准备把这些地址写入全局 baseUrl 或持久化
- THEN 仅接受 `Uri.tryParse` 成功、scheme 为 https、host 非空的条目
- AND 不合规条目被丢弃并记录日志，不参与 baseUrl 选择、不参与轮转、不写回本地持久化
- AND 全部条目不合规时保持当前 baseUrl 不变
- AND 合规条目正常生效，Bearer Token 只可能发往通过校验的 https 主机
验收：A3

## 本地数据容错

### Scenario: 会话解码容错
- GIVEN secure storage 或旧版 SharedPreferences 中存在 `key_auth_session` / `key_user`
- WHEN 该值为畸形 JSON、合法 JSON 但非对象、或字段类型异常
- THEN 启动过程不抛出 FormatException/TypeError
- AND 对应的坏键被删除（记录日志），应用按「未登录」继续启动并进入登录引导
- AND 其余初始化与正常登录态恢复不受影响
- AND 存在畸形数据的回归测试覆盖 secure 路径与旧 prefs 路径
验收：A4

### Scenario: 启动响应容错
- GIVEN startup 接口返回的 `recent_keywords` / `recent_magnet_keywords` 含非字符串元素，或 `settings` / `user` 类型与约定不符
- WHEN 客户端解析 StartupData
- THEN 热词列表跳过非字符串项并保留合法项，`settings`/`user` 解析失败时降级为空/null
- AND 启动整体成功，异常字段不影响其他字段与后续流程
验收：A5

## 认证与会话

### Scenario: 登出失败安全
- GIVEN 用户已登录并点击「退出登录」，或会话过期触发全局登出
- WHEN 安全存储写入 tombstone 失败
- THEN 内存中的 token/user 仍被清空并通知监听者，界面进入未登录态
- AND 持久化失败被捕获并记录日志，异常不向调用方逃逸
- AND 个人页退出流程有异常保护，失败时仍能跳转首页；关注标签等缓存不会被先清空
- AND 会话过期分支能正常重定向到登录页，不会被 `isLogged` 拦截回首页
验收：A6

### Scenario: 登录态路由守卫
- GIVEN GoRouter 已创建，认证状态可能在运行期变化
- WHEN 未登录用户尝试进入 `/profile/**`，或用户登出/被踢出
- THEN redirect 按 matchedLocation 将未登录访问重定向到登录页
- AND 认证状态变化会触发路由重新求值（refreshListenable 接入 AuthProvider）
- AND 全局登出使用 go/replace 清理受保护页面，返回键不能回到已登出的受保护页
验收：A7

### Scenario: 登录注册错误解包
- GIVEN 登录或注册请求失败（密码错误、参数无效、服务端 5xx、响应缺少 token/user）
- WHEN 页面处理错误
- THEN 从 `DioException.error` 解包 ApiException 并展示服务端中文 message
- AND 用户可见文案不出现 “DioException [bad response]”/“Error: ApiException” 等英文技术串
- AND 缺少 token/user 时给出明确中文提示而不是 TypeError
- AND 有测试断言错误文案
验收：A17

### Scenario: 换号清理关注缓存
- GIVEN 用户已登录账号 A 且存在关注标签缓存
- WHEN 通过设置页「认证 Token」弹窗换入账号 B 的 token 并保存会话
- THEN 关注标签缓存被清空或按账号 B 重新同步
- AND 下次冷启动不会把账号 A 的标签作为 batch_push 提交给账号 B
验收：A22

## 个人中心

### Scenario: “我看过的”真实数据
- GIVEN 用户已登录且服务端存在看过记录
- WHEN 用户从个人页进入「我看过的」
- THEN 页面使用真实 `status=watched` 数据源分页展示影片
- AND 顶部类型 Tab 与筛选入口不再共用空 controller/空回调，切换 Tab 或筛选会反映到列表
- AND 无记录时才显示空态
验收：A8

## 播放器与详情页

### Scenario: 预告片进度条 seek
- GIVEN 预告片操作层显示底部进度条
- WHEN 用户点击或拖动进度条
- THEN seek 目标按进度条自身宽度换算（分母等于进度条渲染宽度），而不是整屏宽度
- AND 点击进度条最右端 seek 到接近视频结尾，填充随手指位置同步
- AND 有测试断言 seek 目标位置
验收：A9

### Scenario: 操作层自动隐藏
- GIVEN 操作层处于可见状态且自动隐藏计时器已到点或被取消
- WHEN 播放从缓冲/暂停/完成状态恢复到可自动隐藏状态（isPlaying && !isBuffering && !isCompleted 且无错误）
- THEN 重新创建自动隐藏计时器，操作层在超时后自动隐藏
- AND 应用启动后首次播放处于初始缓冲的场景同样能在恢复后自动隐藏
验收：A10

### Scenario: 剧照缩略图解码限制
- GIVEN 详情页「预告片/剧照」区域渲染 164dp 高的剧照缩略图
- WHEN 加载缩略图并测量宽高比
- THEN 解码尺寸按槽位高度×devicePixelRatio 限制（memCacheHeight 等），不再按原图分辨率常驻 ImageCache
- AND 宽高比测量复用同一有界 provider，或直接使用已记忆的宽高比，不额外持有无界全尺寸 provider
- AND 全屏图库仍按原图展示，不受缩略图限制影响
验收：A11

## 列表与榜单

### Scenario: 榜单分页推断
- GIVEN 榜单接口响应缺少 `total_pages`
- WHEN 客户端解析分页信息
- THEN `totalPages` 按「本页条目数 >= pageSize 时 page + 1，否则 page」推断
- AND 服务端返回 `current_page` 前移时当前页判断仍正确
- AND 有码/无码/欧美/FC2 榜单在首屏满页时能继续加载第 2 页
验收：A12

### Scenario: Top250 名次
- GIVEN Top250 响应中的影片带有服务端 `ranking` 字段，且可能开启「未标看过」过滤
- WHEN 列表渲染名次
- THEN 使用服务端 `ranking` 作为徽章名次（可跳号），缺失时才回退为 startRank+index
- AND 末页判断按 start_rank 上限或 total 收敛，不因过滤后的短页提前截断后续名次
验收：A13

### Scenario: 列表加载失败守卫
- GIVEN `PaginatedListView`、`MovieGridView` 或 `ActorGridView` 的加载更多请求失败（error 非空）
- WHEN 用户继续滚动（含惯性滚动逐帧通知）
- THEN 滚动监听不再调用 fetchMore 自动重发请求
- AND 底部保留「重试」按钮，只有用户点击按钮才重新请求
- AND 失败前已有的条目与滚动位置不受影响
验收：A14

## 错误文案与错误态

### Scenario: 统一错误文案
- GIVEN 页面或列表请求失败
- WHEN 渲染 ErrorRetryWidget 或首页分区错误态
- THEN 文案来自 `userFacingErrorMessage(Object error)`：ApiException 使用服务端中文 message；连接/超时使用“网络连接失败，请检查网络”；其余使用“加载失败，请重试”
- AND 用户可见文案不再包含 `error.toString()` 产生的 DioException 英文技术描述
- AND 原始异常仍写入日志便于排查
验收：A15

### Scenario: 演员详情错误可重试
- GIVEN 演员详情页加载失败
- WHEN 错误态渲染
- THEN 展示中文错误文案与「重试」按钮（ErrorRetryWidget）
- AND 点击重试重置错误/加载状态并重新请求，成功后展示内容
验收：A16

## 无障碍与布局

### Scenario: 表单可滚动
- GIVEN 注册页或登录页展示表单
- WHEN 键盘弹起或系统字号放大导致可用高度不足
- THEN 表单可滚动，提交按钮与错误提示可以滚动到达
- AND 不出现 RenderFlex overflow
验收：A18

### Scenario: 选中态可访问性
- GIVEN 演员卡处于批量操作选中态
- WHEN 渲染选中徽章
- THEN 前景使用 `colorScheme.onPrimary` 或等效语义色，暗色主题下勾选图形对比度不低于 3:1
- AND 徽章不使用字面量颜色；Semantics 暴露 `selected` 状态
验收：A19

### Scenario: 名次徽章可访问性
- GIVEN Top250 列表渲染前三名徽章
- WHEN 渲染名次
- THEN 文字与底色对比度不低于 4.5:1（必要时改用深色前景/新配色）
- AND 读屏语义包含“第 N 名”
验收：A20

### Scenario: 轮播动效控制
- GIVEN 首页推荐轮播可自动切换
- WHEN 系统开启「减少动态效果」，或用户操作暂停/播放
- THEN 开启减少动效时不自动切换
- AND 提供用户可操作的暂停/播放控制，暂停后不再自动轮播
- AND 现有手指按住暂停、松手恢复与滚动行为不回退
验收：A21

## 架构与测试基线

### Scenario: 架构边界收敛
- GIVEN 仓库现有 feature 划分
- WHEN 检查 feature 间依赖与文档
- THEN categories/profile 不再 import following feature，关注按钮位于 `lib/core/widgets/`
- AND 仅做透传的 ProfileFollowingScreen 被删除，路由直接挂载 FollowingScreen
- AND `lib/features/settings/` 死代码被删除，`grep -rn "features/settings" lib test` 无命中
- AND STRUCTURE.md/RULES.md 中关于 settings feature、路由位置与关注按钮归属的描述与实际一致
验收：A23

### Scenario: 实体列表屏收敛
- GIVEN 片商、导演、系列三个页面均为「Tab + 分页列表」
- WHEN 渲染这些页面
- THEN 共用 `lib/core/widgets/entity_tab_list_screen.dart` 的泛型实现，各 feature 只提供数据源与 tile
- AND TabController 长度取自 children 长度，Tab 与内容始终一致
- AND 加载/空态/错误/分页/KeepAlive 行为与改动前一致
验收：A24

### Scenario: 测试补齐
- GIVEN 现有测试套件
- WHEN 执行本批新增测试
- THEN 注册页覆盖两次密码不一致、密码过短、接口报错、成功跳转（含 from）四个分支
- AND 注册 API 测试直接调用 `AuthSessionService.register` 并断言提交字段
- AND 演员详情覆盖筛选 tags/sort/order 参数与信息面板占位符（`--`、`N 岁`）
- AND CachedImage 测试断言 imageUrl（含域名前缀/相对路径拼接）、width、height 透传
验收：A25

### Scenario: 格式基线
- GIVEN 全仓源码
- WHEN 执行 `dart format --output=none --set-exit-if-changed lib test`
- THEN 退出码 0，无文件需要重新格式化
- AND CI 构建流程包含该格式检查步骤
- AND 本次提交中纯格式改动与逻辑改动可区分
验收：A26
