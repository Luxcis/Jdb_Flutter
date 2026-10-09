# Capability: in-app-update（应用内在线更新）

本能力描述应用内更新的完整行为：检查更新、下载安装包、安装触发与安装包哈希校验。功能仅面向 Android。主题与文案遵循项目 RULES（中文硬编码、Material 3）。

## 检查更新（既有行为）

- 检查入口位于「我的-设置」页；使用 `SettingsProvider.githubProxy` 作为 GitHub 代理前缀。
- `UpdateChecker.check()` 请求 `https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest`（按代理规则拼接），解析 `tag_name`、`body` 与 `assets`（含 `digest`）。
- 版本比较使用语义化版本（pub_semver）：latest > current 弹出更新弹窗，否则提示「已是最新版本」；解析失败不视为有更新。

### Scenario: 更新检查行为保持不变

Given 用户在设置页触发检查更新
When GitHub latest release 的版本高于本机版本
Then 弹窗展示新版本号与更新日志，可「稍后再说」或「立即更新」；无更新或请求或解析失败时保持既有提示行为，进入与提示文案不变

## 资产选择与下载（既有行为）

- `UpdateInstaller.pickAsset` 按设备 `supportedAbis` 顺序匹配资产名，无匹配时回退第一个资产。
- 下载流式写入 `<应用文档目录>/update/app-jade.apk`，进度通过回调 `(received, total)` 上报，弹窗以线性进度条与百分比展示；固定文件名与目录不变。

### Scenario: 下载与进度展示保持不变

Given 用户在更新弹窗点击「立即更新」
When APK 正在下载
Then 展示线性进度与百分比，进度回调的行为与目录、固定文件名保持现状；下载失败时弹窗提示失败且可重新下载

## 安装触发与哈希校验（本次新增）

- 下载完成后弹窗进入待安装状态：显示「安装」按钮；用户未点击前不调起系统安装器。
- 点击「安装」时计算已下载 APK 的实际 SHA-256（package:crypto），与期望哈希比对后通过才调起 `OpenFilex` 打开系统安装器。
- 期望哈希优先取 release JSON 中资产自带的 `digest` 字段（`sha256:<hex>`）；缺失时回退下载同名 `<asset名>.sha256` 文件（`sha256sum` 输出格式），取首列哈希为期望值。
- 比对忽略 `sha256:` 前缀与十六进制大小写；期望值缺失、下载失败或格式非法（非 64 位十六进制）一律视为「无法校验」。
- 校验期间弹窗显示「正在校验安装包完整性…」，同一时刻不可重复触发。
- 校验不一致：不调起安装器，删除已下载文件，弹窗提示「安装包校验失败，已阻止安装」，允许重新下载。
- 无法校验（fail-closed）：不调起安装器，保留已下载文件，弹窗提示「无法校验安装包完整性」，允许重试。

### Scenario: 下载完成显示安装入口

Given APK 已下载完成
When 更新弹窗绘制
Then 弹窗处于完成态并展示「安装」按钮，系统安装器未被调起

### Scenario: 校验通过后调起系统安装器

Given 已下载 APK 的实际 SHA-256 与期望哈希一致（期望值来自 `digest` 或 `.sha256` 文件均可）
When 用户点击「安装」
Then 先完成校验再通过 `OpenFilex` 调起系统安装器，弹窗不出现校验失败提示

### Scenario: 校验不一致阻止安装并删除文件

Given 已下载 APK 的实际 SHA-256 与期望哈希不一致
When 用户点击「安装」并完成校验
Then 不调起系统安装器，删除已下载文件，弹窗提示「安装包校验失败，已阻止安装」并允许重新下载

### Scenario: digest 缺失回退 .sha256 文件校验

Given 资产 `digest` 字段缺失且同名 `.sha256` 文件可下载
When 用户点击「安装」
Then 以该文件解析出的期望哈希（首列哈希、忽略 `sha256:` 前缀与十六进制大小写）与实际 SHA-256 比对，校验结果行为与使用 `digest` 时一致

### Scenario: 期望哈希不可用时阻止安装

Given 资产 `digest` 缺失、`.sha256` 文件下载失败或期望值格式非法
When 用户点击「安装」
Then 不调起系统安装器，弹窗提示「无法校验安装包完整性」，保留已下载文件并允许重试；不静默跳过校验直接安装

### Scenario: 校验过程状态展示

Given 校验正在执行
When 更新弹窗绘制
Then 显示「正在校验安装包完整性…」状态且不可重复触发；校验结束后仅有通过（调起安装器）或失败（对应失败提示）两种可见结果

## 打开系统安装器（既有行为）

- 校验通过后经 `OpenFilex.open` 调起；返回非 done 结果时提示「安装包已下载，请在通知栏/文件管理器中安装」。

### Scenario: 调起失败提示保持不变

Given 校验通过且已调用 `OpenFilex.open`
When 返回结果类型不是 done
Then 保持既有降级提示「安装包已下载，请在通知栏/文件管理器中安装」，不因本次改动变化
