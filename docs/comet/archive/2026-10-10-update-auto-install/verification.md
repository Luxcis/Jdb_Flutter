---
generated_from_state_version: 9
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-10-10T02:58:49.246Z
- 摘要: 候选 d5820ca（HEAD）实现「下载完成后自动进入校验并调起安装器」：弹窗下载成功路径直接 await _runInstall() 进入 verifying 并调用 Screen 的 install 编排（校验→通过则 OpenFilex.open→成功关窗），downloaded 仅保留为失败重试态，_startInstall 保留阶段守卫的手动重试入口；Screen 校验→调起编排逻辑未改（仅注释更新），服务层 update_service.dart 与设置页检查状态链路未被本候选改动。复用 Runtime 正式检查（v-analyze 与 v-profile-tests 均 passed）加代码/测试逐项核证，A1–A21 全部 passed，与两项既有行为限制（OpenFilex 外部调起、返回键关闭路径未测）已列入风险。工作区仅含 Runtime 管理的 comet-state.yaml 未提交改动，无实现偏离。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1: APK 下载完成且实际 SHA-256 与期望哈希一致时，弹窗自动进入校验状态并调起系统安装器，全程无需用户点击「安装」；调起成功（`OpenFilex` 返回 done）后弹窗关闭。 | profile_update_dialog.dart L87-90：下载成功先 setState(_apkPath) 后直接 await _runInstall()，不再置 _Phase.downloaded 等待态；_runInstall L104-114 进入 verifying 并调 install 编排（Screen _verifyAndInstallApk L199-212 verified 后 OpenFilex.open），outcome==opened 时 Navigator.pop 关闭弹窗。测试第 68-89 行用例断言 installCalls==1、等待态文案与标题均 findsNothing（弹窗关闭）。 |
| A2 | passed | brief.md | A2: APK 下载完成的瞬间弹窗即展示「正在校验安装包完整性…」，安装编排（校验 + 调起）自动执行且仅执行一次：不存在「下载完成，点击『安装』可开始更新」的首次等待态，也不产生重复调用。 | _startDownload 下载完成即同步 await _runInstall()，先 setState(_Phase.verifying) 展示「正在校验安装包完整性…」（L162-168），编排仅自动调用一次；verifying 阶段按钮为禁用的 TextButton(onPressed:null)（L196-197），测试第 150-180 行断言点击校验中按钮后 installCalls 仍为 1，且「下载完成，点击『安装』可开始更新」在成功路径 findsNothing。 |
| A3 | passed | brief.md | A3: 自动校验结果为不一致时弹窗行为与既有分支一致：不调起安装器、删除已下载文件、提示「安装包校验失败，已阻止安装」，并保留「重新下载」入口；重新下载完成后再次自动进入校验流程。 | Screen _verifyAndInstallApk L204-205 mismatch 分支先 await installer.deleteApk(apkPath) 再返回 hashMismatch（update_service.dart L282-291 删除文件），弹窗 _runInstall L117-124 置 downloaded+hashMismatch 失败提示，_buildActionButtons L201-209 needsRedownload 显示「重新下载」接 _startDownload；测试第 182-215 行验证失败提示与入口，且重下后 installCalls==2 再次自动进入校验（第二次成功后弹窗关闭）。 |
| A4 | passed | brief.md | A4: 自动校验结果为无法校验（期望哈希缺失/非法、文件不可读）时弹窗 fail-closed：不调起安装器、保留已下载文件、提示「无法校验安装包完整性，已阻止安装」，并保留「安装」按钮供手动重试重验。 | Screen L206-207 unavailable 分支直接返回 hashUnavailable，不调 OpenFilex、不删文件（与 mismatch 分支不同）；弹窗提示「无法校验安装包完整性，已阻止安装」且 needsRedownload==false 保留「安装」按钮接 _startInstall 手动重试；测试第 217-236 行断言该文案、「安装」存在与「重新下载」findsNothing。update_service.dart L258-261 期望哈希解析失败即返回 unavailable，fail-closed 语义保持。 |
| A5 | passed | brief.md | A5: 校验通过但系统安装器调起失败时弹窗保持既有降级：提示「安装包已下载，请在通知栏/文件管理器中安装」，并保留「安装」按钮供手动重试调起。 | Screen L209-212：OpenFilex.open 返回 type!=done 时返回 openFailed；弹窗 _FailureKind.openFailed 映射提示「安装包已下载，请在通知栏/文件管理器中安装」（L68-69），失败态 _phase=downloaded 且 needsRedownload==false，保留「安装」按钮经 _startInstall（仅 downloaded 阶段放行）手动重试调起；测试第 238-250 行覆盖该提示与「安装」按钮。 |
| A6 | passed | brief.md | A6: 下载完成前弹窗行为不变：弹窗内容展示、下载进度（线性进度条 + 百分比）、下载失败的提示与重新下载入口均与现状一致。 | 候选 diff 未触碰下载段代码：_startDownload 的下载调用、进度 setState(_progress=received/total) 与下载失败 catch 置 idle+「下载失败，请重试」（L91-99）原样保留；_Phase.downloading 渲染 LinearProgressIndicator+百分比（L154-161）不变。测试第 91-119 行验证「正在下载更新… 50%」与失败重试路径（第 252-270 行断言下载失败时 installCalls==0）。 |
| A7 | passed | specs/in-app-update/spec.md | 更新检查行为保持不变 Given 用户在设置页触发检查更新 When GitHub latest release 的版本与本机版本比较完成 Then 有更新时弹出更新弹窗；无更新或请求或解析失败时保持既有提示行为，提示与提示文案进入路径不变 | 回归项：候选 diff（git show d5820ca）仅改 Screen _verifyAndInstallApk 注释、弹窗状态机与测试，_checkForUpdate/UpdateChecker.check 逻辑零改动（update_service.dart L144-168 未变）；profile_settings_update_state_test.dart 全量用例随 v-profile-tests 通过。 |
| A8 | passed | specs/in-app-update/spec.md | 无更新结论使入口变为暂无更新且禁用 Given 用户在设置页触发检查更新且 GitHub latest release 版本不高于本机版本 When 检查返回无更新结论 Then 入口按钮文案变为「暂无更新」且进入禁用态不可点击，仍保留既有 SnackBar「已是最新版本」提示 | 回归项：Screen L145-151 无更新记录结论+「已是最新版本」SnackBar、L318-320 status==upToDate 渲染禁用「暂无更新」按钮均未被本次改动触及；profile_settings_update_state_test.dart 第 134-153 行用例（无更新：按钮变「暂无更新」且禁用，SnackBar 保留）在 v-profile-tests 中通过。 |
| A9 | passed | specs/in-app-update/spec.md | 有更新结论保持既有弹窗与按钮 Given 用户在设置页触发检查更新且 GitHub latest release 版本高于本机版本 When 检查返回有更新结论 Then 弹出更新弹窗（既有流程），入口按钮仍为「检查更新」且可再次触发检查 | 回归项：有更新路径 _showUpdateDialog（L152/L163-173）未改，_buildUpdateButton 仅 upToDate 禁用、其余保持「检查更新」可点击（L310-322）；既有 profile_settings_update_state_test 覆盖并在 v-profile-tests 中通过。 |
| A10 | passed | specs/in-app-update/spec.md | 检查失败不改变入口状态 Given 用户在设置页触发检查更新 When 请求失败（网络异常、非 200 或解析失败） Then 入口按钮保持「检查更新」且可立即重试，提示「检查更新失败，请稍后重试」不变，不记录任何结论 | 回归项：_checkForUpdate catch 分支提示「检查更新失败，请稍后重试」且 _updateCheckSession.record 仅在成功路径调用（L143-157），finally 复位 _checkingUpdate 可立即重试；该逻辑未被候选 diff 触及，既有测试通过。 |
| A11 | passed | specs/in-app-update/spec.md | 同一运行内重进设置页保留检查结论 Given 本次应用运行内已检查出「无更新」结论 When 用户离开设置页后再次进入设置页 Then 入口按钮仍为「暂无更新」且不可点击，不因页面重建而复位 | 回归项：结论存于 UpdateCheckSession（进程级 Listenable，非页面 State），_updateCheckSession.initState 装配默认 UpdateCheckSession.shared（L66-67），重进设置页不复位；测试第 229-255 行「重进页面仍暂无更新」用例未改动并通过。 |
| A12 | passed | specs/in-app-update/spec.md | 状态不持久化且应用重启后复位 Given 任何时刻应用运行内记录过检查结论 When 应用进程重启后进入设置页 Then 入口按钮恢复「检查更新」且可点击；整个功能不向任何持久存储写入状态 | 回归项：UpdateCheckSession 为纯内存 Listenable（update_check_session.dart），无 SharedPreferences/文件写入；候选未改动该链路，update_check_session_test 与 profile_settings_update_state_test 均在 v-profile-tests 通过。 |
| A13 | passed | specs/in-app-update/spec.md | 下载与进度展示保持不变 Given 用户在更新弹窗点击「立即更新」 When APK 正在下载 Then 展示线性进度与百分比，进度回调的行为与目录、固定文件名保持现状；下载失败时弹窗提示失败且可重新下载 | 回归项：UpdateInstaller.download 流式写入 update/app-jade.apk 固定路径、onProgress(received,total) 回调（update_service.dart L198-225）未被候选改动；弹窗进度展示（线性进度条+百分比）与失败重试不变（对应 A6 证据），测试第 112 行「正在下载更新… 50%」通过。 |
| A14 | passed | specs/in-app-update/spec.md | 下载完成后自动校验并调起系统安装器 Given APK 已下载完成且实际 SHA-256 与期望哈希一致（期望值来自 `digest` 或 `.sha256` 文件均可） When 更新弹窗绘制 Then 弹窗自动进入校验状态并完成校验，未经用户点击通过 `OpenFilex` 调起系统安装器；全程不出现「下载完成，点击『安装』可开始更新」等待态 | 与 A1 同一实现路径：下载完成 → setState(_apkPath) → await _runInstall()（verifying 状态+install 编排）；Screen verified 后 OpenFilex.open 调起；期望哈希来自 digest 或 .sha256 均由 installer.verifyApk→resolveExpectedSha256（L230-243，digest 优先、缺失回退 .sha256）统一处理；测试第 68-89 行断言全程无「下载完成，点击『安装』可开始更新」等待态。 |
| A15 | passed | specs/in-app-update/spec.md | 安装流程自动触发且仅触发一次 Given APK 已下载完成且自动安装流程已开始 When 校验与安装编排执行期间 Then 编排仅被自动触发一次，不因弹窗重绘或重复事件而重入；校验结束仅有通过（调起安装器）或失败（对应失败提示）两种可见结果 | 自动触发链为一次性同步序列：_startDownload 完成回调中单次 await _runInstall()；_runInstall 进入 verifying 后仅由 install Future 结束分支（pop 或失败态），无重复事件源；重绘不重入（install 只在该两处调用，且失败态仅暴露手动「安装/重新下载」按钮）。测试第 150-180 行（校验期间重复点击 installCalls 保持 1）、第 68-89 行（installCalls==1）通过。 |
| A16 | passed | specs/in-app-update/spec.md | 自动校验不一致阻止安装并删除文件 Given 已下载 APK 的实际 SHA-256 与期望哈希不一致 When 自动安装流程完成校验 Then 不调起系统安装器，删除已下载文件，弹窗提示「安装包校验失败，已阻止安装」并允许重新下载；重新下载完成后再次自动进入同一校验流程 | 与 A3 同一行为：mismatch → deleteApk + 「安装包校验失败，已阻止安装」+「重新下载」入口；重下完成后 _startDownload 再次自动 await _runInstall() 进入同一校验流程。测试第 182-215 行验证第二次 installCalls==2、显示校验中文案、通过后弹窗关闭。 |
| A17 | passed | specs/in-app-update/spec.md | 期望哈希不可用时阻止安装 Given 资产 `digest` 缺失、`.sha256` 文件下载失败或期望值格式非法 When 自动安装流程完成校验 Then 不调起系统安装器，弹窗提示「无法校验安装包完整性，已阻止安装」，保留已下载文件并保留「安装」按钮供用户手动重试；不静默跳过校验直接安装 | 与 A4 同一 fail-closed 行为：期望哈希缺失（digest 空串且 .sha256 非 200/异常，update_service.dart L238-242）、格式非法（parseApkDigest 非 64 位十六进制返回 null）、本地文件不可读（computeFileSha256 catch）均返回 unavailable → 不调 OpenFilex、不删文件，弹窗提示「无法校验安装包完整性，已阻止安装」并保留「安装」手动重试；update_service_test 覆盖 resolveExpectedSha256/verifyApk fail-closed 分支且通过；不静默跳过校验（unavailable 分支无任何调起路径）。 |
| A18 | passed | specs/in-app-update/spec.md | digest 缺失回退 .sha256 文件校验 Given 资产 `digest` 字段缺失且同名 `.sha256` 文件可下载 When 安装流程执行校验（自动触发或失败后手动重试均可） Then 以该文件解析出的期望哈希（首列哈希、忽略 `sha256:` 前缀与十六进制大小写）与实际 SHA-256 比对，校验结果行为与使用 `digest` 时一致 | 回归项：resolveExpectedSha256 优先 digest、缺失回退下载同名 <downloadUrl>.sha256 并按 parseApkDigest 解析（首列哈希、忽略 sha256: 前缀与大小写，update_service.dart L111-124/L230-243）未被候选改动；update_service_test 第 314-465 行覆盖（digest 优先不发包、缺失下载 .sha256、非法回退、sha256sum 首列解析、按文件内容校验）并在 v-profile-tests 通过。 |
| A19 | passed | specs/in-app-update/spec.md | 校验过程状态展示 Given 校验正在执行（自动触发或失败后手动重试） When 更新弹窗绘制 Then 显示「正在校验安装包完整性…」状态且不可重复触发 | _runInstall 入口先 setState(_Phase.verifying)，verifying 渲染「正在校验安装包完整性…」+「校验中…」禁用按钮（L162-168/L196-197），_startInstall 仅在 _Phase.downloaded 放行、下载成功路径不再经过 downloaded，故校验中不可重复触发（手动重试同样经 _runInstall）；测试第 166-175 行断言文案、无「安装」按钮、重复点击 installCalls 保持 1。 |
| A20 | passed | specs/in-app-update/spec.md | 弹窗已关闭时不自动安装 Given APK 下载完成时更新弹窗已关闭 When 下载返回完成 Then 不执行校验也不调起系统安装器，已下载文件保留在原路径，等待下一次检查更新重新下载覆盖 | _startDownload 下载完成后检查 if (!mounted) return;（L87），弹窗已卸载时不进入 _runInstall，无校验、无 OpenFilex 调起，文件保留原路径等待下次检查更新重新下载覆盖；测试第 121-148 行「弹窗已关闭时不自动安装」用卸载 widget 树后完成下载门闩，断言 installCalls==0。已知限制：未覆盖系统返回键关闭路径，但 mounted 检查与关闭方式无关，语义等价。 |
| A21 | passed | specs/in-app-update/spec.md | 调起失败提示保持不变 Given 校验通过且已调用 `OpenFilex.open` When 返回结果类型不是 done Then 保持既有降级提示「安装包已下载，请在通知栏/文件管理器中安装」，不因本次改动变化 | Screen L209-212：OpenFilex.open 返回非 done（如 openFailed 类型）时返回 ApkInstallOutcome.openFailed，弹窗映射既有降级提示「安装包已下载，请在通知栏/文件管理器中安装」（_failureMessage L68-69），该提示文案与映射在本次候选 diff 中零改动（仅触发时机变化），测试第 238-250 行断言该文案。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze --no-pub | analyze --no-pub | . | passed | 0 | 2991 ms |
| flutter test test/features/profile --no-pub（131 用例，含弹窗自动触发 9 个用例） | test test/features/profile --no-pub | . | passed | 0 | 6281 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze --no-pub: passed — —
- flutter test test/features/profile --no-pub: passed — —
- 已知限制: OpenFilex 真实调起为外部系统能力，widget 测试以 install 回调结果驱动弹窗行为，真实调起仅能在设备上人工复核
- 已知限制: A20（弹窗已关闭不自动安装）通过卸载 widget 树模拟关闭时序，未覆盖系统返回键关闭路径

## 阻塞项

_无。_

## 风险与跳过的工作

- OpenFilex 真实调起为外部系统能力：widget 测试以 install 回调返回的 ApkInstallOutcome 驱动弹窗行为，OpenFilex.open 的 ResultType 映射（done→opened/非 done→openFailed）无自动化测试覆盖，仅 Screen L209-212 代码级核实。
- A20 通过卸载 widget 树模拟弹窗关闭时序，未覆盖系统返回键关闭路径；因 mounted 检查与关闭方式无关，判定语义等价，真机时序差异仍属残余风险。
- 运行时检查证据为 Runtime 在候选 d5820ca 上执行的 flutter analyze --no-pub 与 flutter test test/features/profile --no-pub（均 passed，exit 0），未覆盖 test/ 全目录；但本需求改动仅涉 test/features/profile 与 lib/features/profile，风险有限。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 候选 d5820ca（HEAD）实现「下载完成后自动进入校验并调起安装器」：弹窗下载成功路径直接 await _runInstall() 进入 verifying 并调用 Screen 的 install 编排（校验→通过则 OpenFilex.open→成功关窗），downloaded 仅保留为失败重试态，_startInstall 保留阶段守卫的手动重试入口；Screen 校验→调起编排逻辑未改（仅注释更新），服务层 update_service.dart 与设置页检查状态链路未被本候选改动。复用 Runtime 正式检查（v-analyze 与 v-profile-tests 均 passed）加代码/测试逐项核证，A1–A21 全部 passed，与两项既有行为限制（OpenFilex 外部调起、返回键关闭路径未测）已列入风险。工作区仅含 Runtime 管理的 comet-state.yaml 未提交改动，无实现偏离。 | 2026-10-10T02:58:49.246Z |



## 结论

候选 d5820ca（HEAD）实现「下载完成后自动进入校验并调起安装器」：弹窗下载成功路径直接 await _runInstall() 进入 verifying 并调用 Screen 的 install 编排（校验→通过则 OpenFilex.open→成功关窗），downloaded 仅保留为失败重试态，_startInstall 保留阶段守卫的手动重试入口；Screen 校验→调起编排逻辑未改（仅注释更新），服务层 update_service.dart 与设置页检查状态链路未被本候选改动。复用 Runtime 正式检查（v-analyze 与 v-profile-tests 均 passed）加代码/测试逐项核证，A1–A21 全部 passed，与两项既有行为限制（OpenFilex 外部调起、返回键关闭路径未测）已列入风险。工作区仅含 Runtime 管理的 comet-state.yaml 未提交改动，无实现偏离。
