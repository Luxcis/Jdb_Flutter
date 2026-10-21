# 目标

在影片详情页信息卡的操作按钮组中，"想看"按钮左侧新增"在线播放"按钮：点击后弹出底部抽屉，按固定顺序列出可用的在线播放源（Jable、SupJav、MissAV），用户点选某个源后抽屉关闭，并用系统浏览器打开"该源 URL 模板 + 当前影片番号"拼出的链接。播放源以"策略 + 注册表"模式实现，新增播放源只需追加一个源定义，UI 与其余代码零改动。

# 范围

- 按钮组 `MovieReviewActions`（`lib/features/movie_detail/widgets/movie_review_actions.dart`）：新增"在线播放"按钮与 `onOnlinePlay` 回调；按钮在未标记/想看/看过三种标记状态下均显示且始终位于按钮组首位（未标记状态下即位于"想看"左侧）；既有按钮的文案、样式、Key、顺序与行为全部不变。
- 回调透传链（`movie_info_card.dart`、`basic_info_widgets.dart`、`movie_detail_screen.dart`）：按既有 `onWantWatch` 等回调模式新增 `onOnlinePlay` 透传。
- 详情页 Screen：提供 `_showOnlinePlaySources`——弹出底部抽屉列出播放源，点选后用 `url_launcher`（`LaunchMode.externalApplication`）打开对应链接，调起失败时 SnackBar 提示。
- 新增播放源模型与注册表（`lib/features/movie_detail/models/online_play_source.dart`）：`OnlinePlaySource` 抽象（id/label/buildUrl(number)）、URL 模板实现、内置三源注册表（顺序：Jable → SupJav → MissAV）。
- 新增底部抽屉（`lib/features/movie_detail/widgets/online_play_source_sheet.dart`）：从注册表渲染源列表，点击条目回调源与已构造链接。

## 目录结构

### 新建

- `lib/features/movie_detail/models/online_play_source.dart`：播放源抽象、URL 模板实现与内置源注册表。
- `lib/features/movie_detail/widgets/online_play_source_sheet.dart`：在线播放源选择底部抽屉。
- `test/features/movie_detail/online_play_source_test.dart`：注册表与 URL 构造单测。
- `test/features/movie_detail/online_play_source_sheet_test.dart`：抽屉 widget 测试。

### 修改

- `lib/features/movie_detail/widgets/movie_review_actions.dart`：新增"在线播放"按钮与回调。
- `lib/features/movie_detail/widgets/movie_info_card.dart`：透传 `onOnlinePlay`。
- `lib/features/movie_detail/widgets/basic_info_widgets.dart`：透传 `onOnlinePlay`。
- `lib/features/movie_detail/screens/movie_detail_screen.dart`：抽屉弹出与浏览器打开逻辑。
- `test/features/movie_detail/movie_review_actions_test.dart`：覆盖新增按钮（三种状态）与回调。
- `pubspec.yaml`：新增 `url_launcher` 依赖（`pubspec.lock` 随之最小更新）。
- `android/app/src/main/AndroidManifest.xml`：新增 `<queries>` 声明（ACTION_VIEW + https scheme），保证 Android 11+ 可解析外部浏览器。

### 删除

（无）

### 明确不建

- 不改 `lib/features/settings/`（项目中的死代码目录，真设置页在 `features/profile`）。
- 不新增路由页面；抽屉为页面内 `showModalBottomSheet`。

# 非目标

- 不在 App 内解析或播放这些站点的内容（内置正片在线播放属 `dev-missav` 工作线，与本 change 无关）。
- 不跟随/联动设置页"在线播放源"选项（该设置属 `dev-missav` 线；本 change 用固定三源，且本 change 基于 dev，dev 上无该设置）。
- 不做播放源顺序持久化、默认源记忆或"记住上次选择"：每次点击"在线播放"都从抽屉重新选择。
- 不修改既有按钮（想看/看过/存入清单及其删除态）的文案、样式、Key、顺序与行为。
- 不引入 App 内 WebView。
- 不处理番号与站点内容的匹配校验（如 supjav 实际仅支持数字 ID 时链接无效，属用户已知范围，按给定模板拼接）。

# 验收示例

- A1: 详情页按钮组三种标记状态均包含"在线播放"按钮且位于首位：未标记状态顺序为 在线播放、想看、看过、存入清单；want_watch 状态为 在线播放、删除想看、看过、存入清单；watched 状态为 在线播放、删除看过、存入清单。
- A2: 点击"在线播放"弹出底部抽屉，按顺序列出三个源 Jable（jable.tv）、SupJav（supjav.com）、MissAV（missav.live），每个条目可点选；抽屉可通过拖动把手、点击遮罩或系统返回关闭，不产生其他副作用。
- A3: 点选某源后抽屉关闭，应用通过系统浏览器打开对应链接；番号 `IPX-538` 时三个源分别打开 `https://jable.tv/videos/ipx-538`、`https://supjav.com/ipx-538`、`https://missav.live/ipx-538`（番号 trim 并转小写后代入模板）。
- A4: 番号 trim 后为空时"在线播放"按钮置灰不可点击，不弹出抽屉。
- A5: 设备无法调起浏览器时，显示 SnackBar"无法打开链接，请检查设备上的浏览器"，应用不崩溃；该失败不影响抽屉的再次使用。
- A6: `flutter analyze --no-pub` 零告警；`flutter test` 全量通过；新增单测覆盖注册表顺序/标识与三个源的小写化 URL 构造，新增抽屉测试覆盖源列表与点击回调，按钮组测试覆盖三种状态与回调触发。

# 约束与不变量

- 播放源注册表是唯一事实来源：抽屉 UI 与 URL 构造只读注册表，不在其他位置散落硬编码播放源 URL。
- 链接必须经系统浏览器打开（`url_launcher` + `LaunchMode.externalApplication`），不在 App 内嵌 WebView，不经内置播放器。
- 既有按钮行为不变：review 三态的按钮集合、Key、文案、样式与"存入清单"位置全部保持现状；新增按钮不影响 `Wrap` 布局与无障碍语义（新按钮自带按钮语义）。
- 遵循 RULES.md：新增文件只进 `features/movie_detail` 的 `models/`、`widgets/`、`screens/`；文案中文硬编码；Material 3；无触觉反馈；无本地化文件。
- `pubspec.lock` 保持锁定版本最小 diff：使用 `PUB_HOSTED_URL=https://pub.flutter-io.cn flutter pub get`（或等效最小变更），不重写无关依赖。
- 结构规则遵守 `STRUCTURE.md` 与 review-fixes-structure-ui 达成的新约定：screen/widget 不直连 `ApiClient`（本 change 不涉及网络请求，天然满足）；`lib/core` 不新增对 feature 的依赖。

# 决策

- D1（用户决定）：change 基于 `dev` 分支（`--target-branch dev`），与 `dev-missav` 线分离，避免与该线详情页改动合并冲突。
- D2（用户决定）："在线播放"按钮放在"想看"按钮左侧，实现为按钮组首位；三种标记状态下均显示（按钮与 review 状态无关）。
- D3（Agent 决定）：采用"策略 + 注册表"模式——`OnlinePlaySource` 抽象定义 `buildUrl(number)`，`UrlTemplateOnlinePlaySource` 以 URL 模板字符串实现通用构造；内置三源以 `const` 列表注册。新增源时：模板式源只需在注册表追加一条 const 定义；需要特殊构造的源可新增实现类。抽屉与按钮逻辑零改动。
- D4（Agent 决定，供最终确认复核）：番号代入模板前 `trim()` 并转小写——Jable 与 MissAV 的站点 URL slug 为全小写，数据库常见大写番号（如 `IPX-538`）直接拼接会得到 404 链接；小写化是这两个站点的实际 URL 规则。SupJav 按用户给定模板原样拼接番号（同样小写化，保持统一）。若用户希望原样代入大小写，可否决此项。
- D5（Agent 决定）：浏览器调起使用 `url_launcher` 最新 6.x（`externalApplication` 模式）；Android 11+ 的包可见性要求在 `AndroidManifest.xml` 声明 `<queries>` 的 `ACTION_VIEW` + `https` scheme，缺失会导致部分设备 `ActivityNotFoundException`。iOS 端 `canLaunchUrl` 需 `LSApplicationQueriesSchemes`，但本项目当前以 Android 为主（CI 仅构建 APK），iOS 配置不在范围内。
- D6（Agent 决定）：番号空白（`trim()` 后为空）时按钮置灰（`onPressed: null`）；浏览器调起失败走 SnackBar 提示并保留抽屉可复用，不做重试队列。

# 待解决问题

（当前无待回复问题。D4 的番号小写化与 D3 的模式形态将在最终确认摘要中呈现，供用户否决或修正。）

# 验证预期

- `flutter analyze --no-pub` 零新增告警；`flutter test` 全量通过。
- 新增 `online_play_source_test.dart`：注册表顺序与 id/label、三个源 `buildUrl` 的小写化代入与空白番号处理。
- 新增 `online_play_source_sheet_test.dart`：抽屉按序列出三源、点击回调携带对应源、番号代入的链接展示/传出正确。
- `movie_review_actions_test.dart` 更新：三种状态下按钮集合与顺序、点击"在线播放"触发 `onOnlinePlay`、番号空白时按钮禁用。
- `movie_detail_screen` 既有测试回归通过；抽屉弹出路径如可行则补屏幕级测试（点在线播放 → 抽屉出现）。
