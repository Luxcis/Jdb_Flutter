# Task 2 Report: AppConstants + StorageKeys/StorageService

## What was implemented

Three files created exactly per the brief (verbatim values, no extra methods/fields — YAGNI):

1. **`lib/core/constants/app_constants.dart`** — `AppConstants` class with private constructor and static const fields:
   - `platform = 'android'`, `appChannel = 'google'`, `appVersion = '1.9.29'`, `appVersionNumber = '35'`
   - `defaultBaseUrl = 'https://jdforrepam.com'`, `mainDomain = 'https://jdforrepam.com'`
   - `imageCdnBase = 'https://tp.spfcas.com/rhe951l4q/'`, `domainFailureThreshold = 3` (int)

2. **`lib/core/storage/storage_keys.dart`** — two classes:
   - `StorageKeys`: 8 SP key constants (`baseUrl`, `apiDomains`, `token`, `user`, `themeMode`, `defaultFilterTags`, `searchHistory`, `line`)
   - `StorageService`: wraps `SharedPreferences`; private constructor, `create()` async factory, `getString/setString/remove` methods.

3. **`test/core/storage/storage_service_test.dart`** — TDD test verifying read/write + persistence across re-instantiation via `StorageService.create()`.

## TDD Evidence

### RED (Step 2)
Command:
```
flutter test test/core/storage/storage_service_test.dart > /tmp/t2_red.txt 2>&1; echo "EXIT_CODE=$?"
```
Exit code: **1** (non-zero, test failure expected at RED).
Failing output (key excerpt):
```
test/core/storage/storage_service_test.dart:3:8: Error: Error when reading 'lib/core/storage/storage_keys.dart': No such file or directory
import 'package:jade/core/storage/storage_keys.dart';
       ^
test/core/storage/storage_service_test.dart:10:23: Error: Undefined name 'StorageService'.
test/core/storage/storage_service_test.dart:11:26: Error: Undefined name 'StorageKeys'.
...
Failed to load ".../storage_service_test.dart": Compilation failed
00:00 +0 -1: Some tests failed.
```
**Why it failed:** `StorageService` and `StorageKeys` symbols were not defined (file didn't exist). This is the genuine missing-symbol failure required by the brief — not a syntax error introduced on purpose.

### GREEN (Step 5)
Command:
```
flutter test test/core/storage/storage_service_test.dart > /tmp/t2_green.txt 2>&1; echo "EXIT_CODE=$?"
```
Exit code: **0**.
Passing output:
```
00:00 +0: loading .../test/core/storage/storage_service_test.dart
00:00 +0: StorageService 读写 baseUrl 并持久化
00:00 +1: All tests passed!
```
Output is pristine (no stray warnings, no analyzer noise).

## Files changed
- `lib/core/constants/app_constants.dart` (created, 11 lines)
- `lib/core/storage/storage_keys.dart` (created, 27 lines)
- `test/core/storage/storage_service_test.dart` (created, 18 lines)

Total: 3 files, 56 insertions, 0 deletions.

## Commit
- Short SHA: **31d5782**
- Subject: `feat(core): add AppConstants and StorageService with persistence`
- Branch: `feature/phase0-foundation` (not switched)
- Staged exactly the 3 files via explicit paths (no `git add -A`).
- Not pushed (as instructed).
- Unrelated files (`docs/superpowers/plans/...`, `.superpowers/`) left untouched.

## Self-Review Findings

- **Persistence genuinely verified:** test calls `StorageService.create()` twice (two separate instances backed by the same `SharedPreferences` mock) and asserts the value written by `svc` is readable by `svc2`. ✓
- **Constants exact:** all 8 values match the brief verbatim, including `appVersionNumber = '35'` (String, not int) and `domainFailureThreshold = 3` (int). ✓
- **No overbuilding:** only the methods/fields specified in the brief were added — `getString`, `setString`, `remove`, `create()`, and the 8 key constants. No extra getters, no clear-all, no caching. ✓
- **RED failure reason is correct:** compilation failed because `storage_keys.dart` did not exist and `StorageService`/`StorageKeys` were undefined — exactly the stated reason. ✓
- **Test output pristine:** GREEN run shows only the standard `+1: All tests passed!` line with no warnings. ✓

## Concerns
None. Task completed cleanly with no deviations from the brief.
