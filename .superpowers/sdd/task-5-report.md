# Task 5: DomainManager 域名状态机 — Report

## What was implemented

Created `lib/core/network/domain_manager.dart` with:

- **`BackupDomainsData`**: minimal Phase-0 placeholder (plain const class, no json_serializable) with `required List<String> apiDomains`.
- **`DomainManager extends ChangeNotifier`**:
  - `String currentUrl` getter
  - `List<String> apiDomains` getter (returns `List.unmodifiable`)
  - `bool isOnMainDomain` getter (compares against `AppConstants.mainDomain` = `https://jdforrepam.com`)
  - `static Future<DomainManager> load(SharedPreferences prefs)`: restores from SP; defaults to `AppConstants.defaultBaseUrl` (`https://staging.letidi.com`) when SP empty
  - `Future<void> applyStartup(BackupDomainsData data)`: sets apiDomains list, resets index to 0, currentUrl to first domain, persists, notifyListeners
  - `Future<bool> rotate()`: cycles to next domain via `(_index + 1) % length`, wraps when exhausted, returns false when ≤1 domains; persists + notifyListeners
  - private `Future<void> _persist()`: writes `StorageKeys.baseUrl` + `StorageKeys.apiDomains`

Test file `test/core/network/domain_manager_test.dart` created verbatim from brief (6 cases, `SharedPreferences.setMockInitialValues({})` in setUp).

## Deviation from brief

The brief's constructor `DomainManager._({required this._prefs})` relies on the **private-named-parameters** language feature, which requires Dart SDK 3.12+. This repo pins `sdk: ^3.8.0`, so the code did not compile. Minimal adaptation made to keep behavior identical:

```dart
// Brief (requires SDK 3.12+):
DomainManager._({required this._prefs}) { ... }

// Adapted (SDK 3.8 compatible, field stays private):
DomainManager._({required SharedPreferences prefs}) : _prefs = prefs { ... }
```

All other code is verbatim from the brief. No functional/behavioral change.

## TDD evidence

### RED (Step 2)

Captured to `/tmp/t5_red.txt`. Exit code 1. Failure was purely missing symbols — not a syntax error — exactly as required by TDD discipline:

```
test/core/network/domain_manager_test.dart:5:8: Error: Error when reading 'lib/core/network/domain_manager.dart': No such file or directory
test/core/network/domain_manager_test.dart:13:22: Error: Undefined name 'DomainManager'.
test/core/network/domain_manager_test.dart:31:27: Error: Method not found: 'BackupDomainsData'.
...
00:00 +0 -1: Some tests failed.
```

### GREEN (Step 4)

Captured to `/tmp/t5_green.txt`. Exit code 0. All 6 cases pass, output pristine:

```
00:00 +0: load 缺省返回 staging 域名
00:00 +1: load 从 SP 恢复已存域名
00:00 +2: applyStartup 写入并持久化主域名
00:00 +3: rotate 顺序轮转并回到首个
00:00 +4: rotate 无备用域名返回 false
00:00 +5: 离开主域名时 isOnMainDomain 为 false
00:00 +6: All tests passed!
```

## Files changed

- `lib/core/network/domain_manager.dart` (created, 69 lines)
- `test/core/network/domain_manager_test.dart` (created, 68 lines)

Staged exactly these two paths; unrelated files untouched. `.superpowers/` left untracked.

## Commit

- SHA: `340427f`
- Subject: `feat(core/network): add DomainManager state machine with persistence`
- Branch: `feature/phase0-foundation` (unchanged)
- Not pushed (per instructions).

## Self-review checklist

- `load()` defaults to `https://staging.letidi.com` when SP empty — YES (case 1)
- `load()` restores both baseUrl and apiDomains from SP — YES (case 2)
- `applyStartup` sets currentUrl to first domain + persists baseUrl & apiDomains — YES (case 3)
- `rotate()` cycles in order, wraps to first when exhausted — YES (case 4)
- `rotate()` returns false when ≤1 domains — YES (case 5)
- `isOnMainDomain` compares against `AppConstants.mainDomain` — YES (case 6)
- `rotate()` persists new currentUrl (re-load would see it) — YES (`_persist()` called before notifyListeners)
- TDD RED + GREEN captured, output pristine — YES

## Concerns

1. **Constructor deviation**: as noted above, the brief's `this._prefs` syntax was incompatible with the pinned SDK. Adaptation is functionally equivalent (private field, public named param). Flagging for visibility in case the brief is re-used in later phases that may need updating.
2. Brief mentions `String toJson()`/`fromJson` persistence in the interface description, but the implementation code block (and tests) do not include those methods. Per YAGNI and the "follow the brief exactly — no extra methods" instruction, omitted. Persistence is handled via SP `setString`/`setStringList` directly.
