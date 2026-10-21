# Capability: online-play-sources（影片详情页在线播放源）

本能力描述影片详情页的"在线播放"入口与播放源选择：详情页操作按钮组中的"在线播放"按钮、点击后的播放源选择底部抽屉、以及用系统浏览器打开"播放源 URL 模板 + 影片番号"链接的完整行为。播放源由统一的源定义（策略）与内置注册表驱动，新增播放源只需追加源定义。文案中文硬编码、Material 3，遵循项目 RULES。

## 播放源定义与注册表

- 播放源抽象 `OnlinePlaySource`（`lib/features/movie_detail/models/online_play_source.dart`）暴露：稳定标识 `id`、展示名 `label`、域名说明 `host`、以及由影片番号构造目标链接的 `buildUrl(number)`。
- 通用实现 `UrlTemplateOnlinePlaySource` 以 URL 模板字符串构造链接：番号经 `trim()` 与小写化后代入 `{number}` 占位符；模板其余部分原样保留。
- 内置播放源注册表为单一 `const` 列表，按显示顺序包含：
  1. Jable：`https://jable.tv/videos/{number}`
  2. SupJav：`https://supjav.com/{number}`
  3. MissAV：`https://missav.live/{number}`
- 注册表是播放源的唯一事实来源：抽屉 UI 与 URL 构造只读注册表，不散落硬编码 URL。新增模板式源只需在注册表追加一条 const 定义；需要特殊构造逻辑的源可新增 `OnlinePlaySource` 实现类，UI 零改动。

### Scenario: 注册表顺序与内置三源

Given 任何调用方读取播放源注册表
When 遍历注册表条目
Then 顺序与内容为 Jable（jable.tv）、SupJav（supjav.com）、MissAV（missav.live），每个条目具备稳定 id、label、host 与可用的 buildUrl

### Scenario: 番号代入模板生成链接

Given 影片番号为 `IPX-538`
When 分别构造三个源的链接
Then 结果依次为 `https://jable.tv/videos/ipx-538`、`https://supjav.com/ipx-538`、`https://missav.live/ipx-538`；番号两侧空白被去除、字母转小写，模板其余部分不变

## 详情页"在线播放"按钮

- 按钮组 `MovieReviewActions` 在原有按钮之前新增"在线播放"按钮（按钮组首位），样式与既有按钮一致（FilledButton、紧凑尺寸）。
- 按钮与影片评鉴（review）标记状态无关：未标记（想看）、想看（删除想看）、看过（删除看过）三种状态下均显示，且既有按钮的文案、Key、顺序与行为不变。
- 影片番号 trim 后为空时按钮置灰（onPressed 为 null），不响应点击。
- 点击"在线播放"仅触发 `onOnlinePlay` 回调；按钮本身不直接弹出抽屉或打开浏览器。

### Scenario: 三种标记状态下按钮组构成

Given 影片详情页分别处于未标记、想看、看过三种标记状态
When 渲染操作按钮组
Then 未标记状态依次为 在线播放、想看、看过、存入清单；想看状态依次为 在线播放、删除想看、看过、存入清单；看过状态依次为 在线播放、删除看过、存入清单；所有既有按钮的文案与 Key 保持不变

### Scenario: 点击在线播放触发回调

Given 影片番号非空且用户点击"在线播放"按钮
When 按钮点击完成
Then 触发 `onOnlinePlay` 回调一次；同一时刻按钮组的其余按钮行为不受影响

### Scenario: 番号空白时按钮禁用

Given 影片番号 trim 后为空字符串
When 渲染操作按钮组
Then "在线播放"按钮呈现禁用态且不可点击，不弹出抽屉；其余按钮不受影响

## 播放源选择抽屉

- 点击"在线播放"后，详情页弹出底部抽屉（`showModalBottomSheet`，带拖动把手），按注册表顺序渲染源列表；每个条目展示源名称与域名说明，整条可点击。
- 抽屉不发起任何网络请求；列表内容完全来自注册表与当前影片番号。
- 抽屉可通过点击遮罩、拖动把手或系统返回关闭；关闭不产生副作用。
- 点选某个源后：抽屉先关闭，再用系统浏览器打开该源构造的链接；同一影片番号在抽屉生命周期内不变。

### Scenario: 抽屉按序展示播放源

Given 用户在详情页点击"在线播放"
When 抽屉弹出
Then 按顺序展示 Jable（jable.tv）、SupJav（supjav.com）、MissAV（missav.live）三个可点击条目，展示名称与域名说明，无网络请求发生

### Scenario: 点选源后关闭抽屉并传出链接

Given 抽屉已弹出且影片番号为 `IPX-538`
When 用户点选 MissAV 条目
Then 抽屉关闭，回调传出 MissAV 源及其构造的链接 `https://missav.live/ipx-538`；点选其他条目同理按各自模板传出

## 用系统浏览器打开链接

- 点选播放源后，应用以 `url_launcher` 的 `LaunchMode.externalApplication` 调起系统浏览器打开链接，优先使用外部浏览器而非应用内视图。
- Android 端在 `AndroidManifest.xml` 声明 `<queries>` 的 `ACTION_VIEW` intent（`https` scheme），保证 Android 11+ 能解析外部浏览器。
- 调起失败（设备无可用浏览器等）时：显示 SnackBar「无法打开链接，请检查设备上的浏览器」，应用保持可用，抽屉可再次打开使用；不做自动重试。

### Scenario: 点选后由系统浏览器打开

Given 用户点选了某个播放源
When 链接构造完成
Then 应用关闭抽屉并以外部浏览器方式打开该链接（`externalApplication`），不在应用内嵌 WebView

### Scenario: 浏览器调起失败降级

Given 设备无法处理目标链接（无可用浏览器）
When 调起失败
Then 显示 SnackBar「无法打开链接，请检查设备上的浏览器」，应用不崩溃，详情页与"在线播放"按钮可继续正常使用
