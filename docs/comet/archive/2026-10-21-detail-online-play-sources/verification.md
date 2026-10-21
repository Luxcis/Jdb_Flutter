---
generated_from_state_version: 8
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-10-21T02:35:57.208Z
- 摘要: A1-A15 全部通过；候选 lock 污染事故已修复并经 enforce-lockfile 与全量测试复核，lock diff 仅 url_launcher 系（64+/8-）

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1: 详情页按钮组三种标记状态均包含"在线播放"按钮且位于首位：未标记状态顺序为 在线播放、想看、看过、存入清单；want_watch 状态为 在线播放、删除想看、看过、存入清单；watched 状态为 在线播放、删除看过、存入清单。 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A2 | passed | brief.md | A2: 点击"在线播放"弹出底部抽屉，按顺序列出三个源 Jable（jable.tv）、SupJav（supjav.com）、MissAV（missav.live），每个条目可点选；抽屉可通过拖动把手、点击遮罩或系统返回关闭，不产生其他副作用。 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A3 | passed | brief.md | A3: 点选某源后抽屉关闭，应用通过系统浏览器打开对应链接；番号 `IPX-538` 时三个源分别打开 `https://jable.tv/videos/ipx-538`、`https://supjav.com/ipx-538`、`https://missav.live/ipx-538`（番号 trim 并转小写后代入模板）。 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A4 | passed | brief.md | A4: 番号 trim 后为空时"在线播放"按钮置灰不可点击，不弹出抽屉。 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A5 | passed | brief.md | A5: 设备无法调起浏览器时，显示 SnackBar"无法打开链接，请检查设备上的浏览器"，应用不崩溃；该失败不影响抽屉的再次使用。 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A6 | passed | brief.md | A6: `flutter analyze --no-pub` 零告警；`flutter test` 全量通过；新增单测覆盖注册表顺序/标识与三个源的小写化 URL 构造，新增抽屉测试覆盖源列表与点击回调，按钮组测试覆盖三种状态与回调触发。 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A7 | passed | specs/online-play-sources/spec.md | 注册表顺序与内置三源 Given 任何调用方读取播放源注册表 When 遍历注册表条目 Then 顺序与内容为 Jable（jable.tv）、SupJav（supjav.com）、MissAV（missav.live），每个条目具备稳定 id、label、host 与可用的 buildUrl | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A8 | passed | specs/online-play-sources/spec.md | 番号代入模板生成链接 Given 影片番号为 `IPX-538` When 分别构造三个源的链接 Then 结果依次为 `https://jable.tv/videos/ipx-538`、`https://supjav.com/ipx-538`、`https://missav.live/ipx-538`；番号两侧空白被去除、字母转小写，模板其余部分不变 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A9 | passed | specs/online-play-sources/spec.md | 三种标记状态下按钮组构成 Given 影片详情页分别处于未标记、想看、看过三种标记状态 When 渲染操作按钮组 Then 未标记状态依次为 在线播放、想看、看过、存入清单；想看状态依次为 在线播放、删除想看、看过、存入清单；看过状态依次为 在线播放、删除看过、存入清单；所有既有按钮的文案与 Key 保持不变 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A10 | passed | specs/online-play-sources/spec.md | 点击在线播放触发回调 Given 影片番号非空且用户点击"在线播放"按钮 When 按钮点击完成 Then 触发 `onOnlinePlay` 回调一次；同一时刻按钮组的其余按钮行为不受影响 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A11 | passed | specs/online-play-sources/spec.md | 番号空白时按钮禁用 Given 影片番号 trim 后为空字符串 When 渲染操作按钮组 Then "在线播放"按钮呈现禁用态且不可点击，不弹出抽屉；其余按钮不受影响 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A12 | passed | specs/online-play-sources/spec.md | 抽屉按序展示播放源 Given 用户在详情页点击"在线播放" When 抽屉弹出 Then 按顺序展示 Jable（jable.tv）、SupJav（supjav.com）、MissAV（missav.live）三个可点击条目，展示名称与域名说明，无网络请求发生 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A13 | passed | specs/online-play-sources/spec.md | 点选源后关闭抽屉并传出链接 Given 抽屉已弹出且影片番号为 `IPX-538` When 用户点选 MissAV 条目 Then 抽屉关闭，回调传出 MissAV 源及其构造的链接 `https://missav.live/ipx-538`；点选其他条目同理按各自模板传出 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A14 | passed | specs/online-play-sources/spec.md | 点选后由系统浏览器打开 Given 用户点选了某个播放源 When 链接构造完成 Then 应用关闭抽屉并以外部浏览器方式打开该链接（`externalApplication`），不在应用内嵌 WebView | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |
| A15 | passed | specs/online-play-sources/spec.md | 浏览器调起失败降级 Given 设备无法处理目标链接（无可用浏览器） When 调起失败 Then 显示 SnackBar「无法打开链接，请检查设备上的浏览器」，应用不崩溃，详情页与"在线播放"按钮可继续正常使用 | 只读 Verifier 独立核实：实现与测试满足该验收项（并实测 analyze 零告警、全量 973 测试通过） |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze --no-pub | analyze --no-pub | . | passed | 0 | 6062 ms |
| flutter test（全量） | test | . | passed | 0 | 35722 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze --no-pub: passed — No issues found! (ran in 4.2s)
- flutter test test/features/movie_detail/: passed — 159 passed
- flutter test（全量）: passed — 973 passed
- 已知限制: launchUrl 的真实调起与设备无浏览器的降级路径未做自动化测试（需 platform channel mock 或真机人工验证）；模型层 URL 构造、抽屉传出链接、按钮置灰均已由测试覆盖，A14/A15 建议在设备上人工复核
- 已知限制: SupJav 按用户给定模板 https://supjav.com/{番号} 拼接；该站点实际以数字 ID 组织 URL 时该链接可能无效，属需求已知范围（Non-goals 已声明不校验匹配）

## 阻塞项

_无。_

## 风险与跳过的工作

- 候选发布后 lock 曾被污染并已修复：当前候选（amend 后）的 pubspec.lock 为最小 diff（基线 + url_launcher 系 8 包、移除无人依赖的 jni_util），enforce-lockfile 验证通过，analyze 与全量测试在干净 lock 下复跑通过

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | A1-A15 全部通过；候选 lock 污染事故已修复并经 enforce-lockfile 与全量测试复核，lock diff 仅 url_launcher 系（64+/8-） | 2026-10-21T02:35:57.208Z |



## 结论

A1-A15 全部通过；候选 lock 污染事故已修复并经 enforce-lockfile 与全量测试复核，lock diff 仅 url_launcher 系（64+/8-）
