# 设置页线路切换设计

## 目标

在设置页（`/profile/settings`）实现 API 域名线路切换：用户可手动选择固定线路
域名，或回到“自动”模式。手动选择立即生效并持久化，重启后保持；自动模式下
沿用现有 608 自动轮转行为，手动模式下禁用轮转。

## 范围

- 扩展 `DomainManager`，新增线路模式（自动/手动）状态与选择方法。
- 设置页「线路选择」占位项替换为可交互入口，弹出底部选择弹窗。
- 将 `DomainManager` 暴露到 Provider 树，供设置页监听。
- 手动选择线路时同步业务 `ApiClient.baseUrl`，立即生效。
- 不新增第三方依赖；不实现线路连通性测试；不改动域名列表来源（startup）。

## 方案

采用“扩展 `DomainManager`”的单一状态源方案：

- `DomainManager` 是域名状态机，已是 `ChangeNotifier`，线路模式并入后设置页
  可直接 `context.watch` 实时刷新。
- 手动模式由 `rotate()` 返回 `false` 表达，`DomainSwitchInterceptor` 现有逻辑
  天然停止轮转，拦截器零改动。
- 模式持久化复用已定义但未使用的 `StorageKeys.line`（`key_line`）。

## 组件职责

### `DomainManager` 扩展

- 新增枚举 `LineMode { auto, manual }` 与字段 `_lineMode`，默认 `auto`。
- getter：`lineMode`、`isAutoMode`。
- `select(String url)`：置 `manual`，将 `_currentUrl` 切换为 `url`，持久化
  `key_line = url`，`notifyListeners()`。
- `selectAuto()`：置 `auto`，恢复主域名（`apiDomains` 首个，为空时保持当前
  地址），持久化 `key_line = 'auto'`，`notifyListeners()`。
- `rotate()`：`manual` 模式下直接返回 `false`（无可用备用域名语义），不切换。
- `applyStartup()`：写入新域名列表后，若当前为 `manual` 且手动选择的域名仍在
  新列表中，维持 `manual` 与该域名；否则回退 `auto` 并切到新列表首个域名。
- `load()`：从 SP 恢复域名列表的同时恢复 `_lineMode`（`key_line == 'auto'`
  或缺省为 `auto`，否则为 `manual` 且 `_currentUrl` 即手动域名）。

### 设置页（`ProfileSettingsPage`）

- 「线路选择」占位项替换为可交互 `ListTile`：
  - `context.watch<DomainManager>()` 实时刷新 subtitle：`auto` 显示「自动」，
    `manual` 显示当前域名去掉 `https://` 前缀的 host。
  - onTap 弹出线路选择弹窗。
- 弹窗为 `showModalBottomSheet`，内容：
  - 标题「线路选择」。
  - 「自动（推荐）」单选行，副标题“请求失败时自动切换可用线路”。
  - 分隔线。
  - 每个 `apiDomains` 域名一个单选行，显示 host，当前选中项高亮。
  - 域名列表为空（startup 未成功过）时，仅显示兜底域名单选行。
  - 选择后调用 `DomainManager.select()/selectAuto()` 与
    `ApiClient.swapBaseUrl()`，关闭弹窗并 `SnackBar` 提示
    「已切换到 xxx」/「已切换到自动线路」。

### 装配

- `main.dart` 的 `MultiProvider` 增加
  `ChangeNotifierProvider.value(value: apiClient.domainManager)`。

## 切换流程

1. 用户点击设置页「线路选择」，弹出底部弹窗，展示自动 + 域名列表。
2. 用户选择一个域名：`DomainManager.select(url)` 置手动并持久化，
   `ApiClient.swapBaseUrl(url)` 使后续请求立即走新线路，关闭弹窗提示成功。
3. 用户选择「自动」：`selectAuto()` 置自动并恢复主域名，
   `ApiClient.swapBaseUrl(主域名)`，后续请求恢复 608 自动轮转。
4. 重启后：`DomainManager.load()` 恢复上次模式与域名；startup 成功后再经
   `applyStartup()` 保持手动选择或按失效回退。

## 错误处理

- 手动域名不在 startup 新列表时回退自动模式并切到主域名，不保留失效地址。
- `apiDomains` 为空时弹窗仅展示兜底域名，选择兜底域名为手动模式，语义一致。
- `select()`/`selectAuto()` 持久化失败不影响内存状态，下次启动以内存为准
  重新持久化。

## 测试与验收

按 TDD 顺序增加以下回归覆盖：

1. `select()` 后 `lineMode == manual`、`currentUrl` 更新且 `key_line` 持久化。
2. `selectAuto()` 后恢复 `auto` 与主域名，`key_line` 持久化为 `'auto'`。
3. `manual` 模式下 `rotate()` 返回 `false` 且不改动 `currentUrl`。
4. `applyStartup()`：手动域名仍在新列表时保持；不在时回退 `auto` 并切主域名。
5. `load()` 能从 SP 恢复 `manual` 模式与手动域名。
6. 拦截器测试：`manual` 模式下 608 错误不触发轮转。
7. 设置页 Widget 测试：点击「线路选择」弹出弹窗；选中域名后 subtitle 更新为
   对应 host；选中「自动」后 subtitle 恢复「自动」；选择后出现 SnackBar。

验证顺序为目标单元测试、目标 Widget 测试、网络拦截器回归测试、静态分析，
最后运行完整测试套件并如实记录既有无关失败。
