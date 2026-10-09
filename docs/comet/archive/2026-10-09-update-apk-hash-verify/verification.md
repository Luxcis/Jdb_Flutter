---
generated_from_state_version: 11
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 2
- 完成时间: 2026-10-09T05:48:42.591Z
- 摘要: 15 项验收全部通过：下载完成→点击「安装」→SHA-256 校验→通过才调 OpenFilex 的两步流实现与验收文字一致，fail-closed 与既有行为保持

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1: 下载完成后进入待安装状态：下载进度完成后弹窗停在完成态并显示「安装」按钮；用户未点击「安装」前不调起系统安装器。 | 弹窗 _startDownload 完成后停在 downloaded 完成态并显示「安装」按钮，测试断言未点击前 installCalls==0 |
| A2 | passed | brief.md | A2: 校验通过安装：点击「安装」时计算已下载 APK 的实际 SHA-256，与期望哈希一致（无论期望值来自资产 `digest` 还是 `.sha256` 文件）时调起系统安装器，弹窗不出现失败提示。 | _verifyAndInstallApk 经 verifyApk 计算实际 SHA-256 比对，verified 才调 OpenFilex，通过路径无失败提示（测试覆盖 digest 与 .sha256 两来源） |
| A3 | passed | brief.md | A3: 校验不一致阻止安装：实际 SHA-256 与期望哈希不一致时不调起系统安装器，删除已下载的损坏文件，弹窗显示「安装包校验失败，已阻止安装」并可重新下载。 | mismatch 分支先 deleteApk 再返回 hashMismatch，不调安装器；弹窗提示「安装包校验失败，已阻止安装」且按钮变为「重新下载」 |
| A4 | passed | brief.md | A4: 回退 `.sha256` 文件校验：资产 `digest` 缺失且同名 `.sha256` 文件可下载时，以该文件解析的期望哈希（取首列哈希、忽略 `sha256:` 前缀与十六进制大小写）完成校验，结果与使用 `digest` 时一致。 | resolveExpectedSha256 在 digest 缺失/非法时下载同名 .sha256（经代理拼接），parseApkDigest 取首列、忽略 sha256: 前缀与大小写；verifyApk 回退校验测试 verified |
| A5 | passed | brief.md | A5: 无法校验时不安装：资产 `digest` 缺失且 `.sha256` 文件不可获取（下载失败或内容非法）时，不调起系统安装器并提示「无法校验安装包完整性」（fail-closed，不静默放行安装）。 | .sha256 请求失败或解析非法时 expected=null→unavailable→hashUnavailable，不调安装器、文件保留可重试，fail-closed |
| A6 | passed | brief.md | A6: 校验过程可见：点击「安装」后的校验期间弹窗显示「正在校验安装包完整性…」，同一时刻不重复触发校验；校验结束后仅有通过或失败两种可见结果。 | verifying 阶段显示「正在校验安装包完整性…」，按钮禁用加 _phase!=downloaded 守卫防重复触发（测试 installCalls==1） |
| A7 | passed | specs/in-app-update/spec.md | 更新检查行为保持不变 Given 用户在设置页触发检查更新 When GitHub latest release 的版本高于本机版本 Then 弹窗展示新版本号与更新日志，可「稍后再说」或「立即更新」；无更新或请求或解析失败时保持既有提示行为，进入与提示文案不变 | UpdateChecker 与检查入口、版本比较、无更新/失败提示未改动，弹窗 idle 态保留新版本号、更新日志、「稍后再说」「立即更新」 |
| A8 | passed | specs/in-app-update/spec.md | 下载与进度展示保持不变 Given 用户在更新弹窗点击「立即更新」 When APK 正在下载 Then 展示线性进度与百分比，进度回调的行为与目录、固定文件名保持现状；下载失败时弹窗提示失败且可重新下载 | download() 目录/固定文件名/进度回调签名未变，弹窗线性进度与百分比保留，下载失败提示「下载失败，请重试」并可重试 |
| A9 | passed | specs/in-app-update/spec.md | 下载完成显示安装入口 Given APK 已下载完成 When 更新弹窗绘制 Then 弹窗处于完成态并展示「安装」按钮，系统安装器未被调起 | 完成态展示「安装」按钮且未点击前系统安装器未被调起（installCalls==0 断言） |
| A10 | passed | specs/in-app-update/spec.md | 校验通过后调起系统安装器 Given 已下载 APK 的实际 SHA-256 与期望哈希一致（期望值来自 `digest` 或 `.sha256` 文件均可） When 用户点击「安装」 Then 先完成校验再通过 `OpenFilex` 调起系统安装器，弹窗不出现校验失败提示 | verified 先于 OpenFilex.open 调起安装器，弹窗通过路径无校验失败提示（findsNothing 断言） |
| A11 | passed | specs/in-app-update/spec.md | 校验不一致阻止安装并删除文件 Given 已下载 APK 的实际 SHA-256 与期望哈希不一致 When 用户点击「安装」并完成校验 Then 不调起系统安装器，删除已下载文件，弹窗提示「安装包校验失败，已阻止安装」并允许重新下载 | mismatch→deleteApk（删除测试覆盖）+hashMismatch，不调起安装器，提示并可重新下载 |
| A12 | passed | specs/in-app-update/spec.md | digest 缺失回退 .sha256 文件校验 Given 资产 `digest` 字段缺失且同名 `.sha256` 文件可下载 When 用户点击「安装」 Then 以该文件解析出的期望哈希（首列哈希、忽略 `sha256:` 前缀与十六进制大小写）与实际 SHA-256 比对，校验结果行为与使用 `digest` 时一致 | digest 缺失回退 .sha256 校验与 digest 路径行为一致（verifyApk 回退测试返回 verified） |
| A13 | passed | specs/in-app-update/spec.md | 期望哈希不可用时阻止安装 Given 资产 `digest` 缺失、`.sha256` 文件下载失败或期望值格式非法 When 用户点击「安装」 Then 不调起系统安装器，弹窗提示「无法校验安装包完整性」，保留已下载文件并允许重试；不静默跳过校验直接安装 | 期望值缺失/下载失败/非法→unavailable→不调起安装器、保留已下载文件、提示「无法校验安装包完整性，已阻止安装」并可重试，不静默跳过 |
| A14 | passed | specs/in-app-update/spec.md | 校验过程状态展示 Given 校验正在执行 When 更新弹窗绘制 Then 显示「正在校验安装包完整性…」状态且不可重复触发；校验结束后仅有通过（调起安装器）或失败（对应失败提示）两种可见结果 | 校验中显示「正在校验安装包完整性…」且不可重复触发；结束后仅 opened（关闭弹窗）或对应失败提示两种可见结果 |
| A15 | passed | specs/in-app-update/spec.md | 调起失败提示保持不变 Given 校验通过且已调用 `OpenFilex.open` When 返回结果类型不是 done Then 保持既有降级提示「安装包已下载，请在通知栏/文件管理器中安装」，不因本次改动变化 | OpenFilex.open 非 done→openFailed，弹窗展示既有降级文案「安装包已下载，请在通知栏/文件管理器中安装」，文案相同（承载位置由 snackbar 改为弹窗） |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze 全项目零问题 | analyze | . | passed | 0 | 3677 ms |
| flutter test test/features/profile 全部通过 | test test/features/profile --no-pub | . | passed | 0 | 6063 ms |
| dart format 检查本轮涉及文件 | format --output=none --set-exit-if-changed lib/features/profile/services/update_service.dart lib/features/profile/widgets/profile_update_dialog.dart lib/features/profile/screens/profile_settings_screen.dart test/features/profile/update_service_test.dart test/features/profile/profile_update_dialog_test.dart | . | passed | 0 | 338 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze（全项目）: passed — No issues found
- flutter test test/features/profile --no-pub（含既有回归 + 本轮新增 28 例）: passed — All 120 tests passed（新增 update_service_test 28 例、dialog 测试 8 例）
- dart format 本轮涉及文件: passed — 格式化通过
- 已知限制: OpenFilex 真实系统调起无法在 widget/单元测试中验证，A2/A10/A15 的测试覆盖止于编排层返回的 outcome 与文案断言；真机行为建议用户验收时确认。
- 已知限制: A15 的降级提示现在在弹窗内展示（与原 ScaffoldMessenger snackbar 同文案），既有文案保留但由弹窗承载。
- 已知限制: 本机 pub 解析历史：flutter pub get 曾把 pubspec.lock 重写为 pub.dev 源，已恢复 HEAD 版本；checks 使用 --no-pub 以避免再次触发重写。
- 已知限制: 屏幕层 _verifyAndInstallApk 在 asset 未知时防御性返回 hashUnavailable（不可达路径），已记录。
- 已知限制: 未做独立预审；正式验收以待提交的独立 Verifier 为准。

## 阻塞项

_无。_

## 风险与跳过的工作

- OpenFilex 真机调起无法在单测/widget 测试验证，A2/A10/A15 覆盖止于编排层 outcome 与文案断言，真机行为建议人工确认
- A15 降级提示承载位置由 ScaffoldMessenger snackbar 改为弹窗内，文案相同但展示位置变化
- 弹窗无法校验文案为「无法校验安装包完整性，已阻止安装」，比验收要求的「无法校验安装包完整性」多后缀，语义一致
- screen 层 _selectedUpdateAsset 为 null 时防御性返回 hashUnavailable（正常流程不可达路径）

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | execution-error | — | 派发的 only-read Verifier 子代理两次执行结束（第二次累计 23 个工具调用）都未返回可用结果：final-result 未提交，/tmp/verifier-final-*.json 未生成，代理最终输出为空。Runtime 状态停在 await-verifier（stateVersion 5，attempt 1，验收 0/15）。请指示重派 Verifier 或返回重试路径。 | 2026-10-09T05:45:47.553Z |
| 1 | 1 | 2 | pass | — | 15 项验收全部通过：下载完成→点击「安装」→SHA-256 校验→通过才调 OpenFilex 的两步流实现与验收文字一致，fail-closed 与既有行为保持 | 2026-10-09T05:48:42.591Z |



## 结论

15 项验收全部通过：下载完成→点击「安装」→SHA-256 校验→通过才调 OpenFilex 的两步流实现与验收文字一致，fail-closed 与既有行为保持
