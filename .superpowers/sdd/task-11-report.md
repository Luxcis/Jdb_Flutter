### Task 11 报告: AuthProvider, StartupProvider, SettingsProvider

**状态**: 完成

**Commit**: `84c756a` — `feat(core/providers): add AuthProvider/StartupProvider/SettingsProvider`

**测试摘要**:
- RED 阶段: 编译失败（AuthProvider 不存在）— 符合预期
- GREEN 阶段: `flutter test test/core/providers/auth_provider_test.dart` — 2/2 通过
  - `login 持久化 token 与 user，isLogged 为 true` ✅
  - `logout 清空 token/user` ✅

**创建的文件**:
- `lib/core/providers/auth_provider.dart` — ChangeNotifier + TokenProvider 实现；login/logout 持久化到 SharedPreferences；create() 工厂从 SP 恢复状态
- `lib/core/providers/startup_provider.dart` — ChangeNotifier；fetchStartup() 调用 /api/v1/startup，解析 backup_domains_data 并 applyStartup；_tryDecodeDomains 返回硬编码兜底域名
- `lib/core/providers/settings_provider.dart` — ChangeNotifier；defaultFilterTags 通过 SP JSON 字符串持久化读写
- `test/core/providers/auth_provider_test.dart` — 2 个 TDD 用例：login 持久化 + 重启恢复，logout 清空

**关注事项**: 无。代码通过 dart analyze（无 issues），测试全部通过。

**报告路径**: `/Users/luxcis/data/workspace/Flutter/Jdb_Flutter/.superpowers/sdd/task-11-report.md`
