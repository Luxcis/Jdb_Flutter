# Task 4 Report: ApiException + Endpoints

## Status: DONE

## What was implemented

Three files created verbatim per `.superpowers/sdd/task-4-brief.md`:

1. **`lib/core/network/api_exception.dart`** — `ApiException implements Exception`:
   - `const ApiException({required this.action, this.message})`
   - `factory ApiException.fromAction(String action, String? message)`
   - `final String action`, `final String? message`
   - `bool get isAuthError` → true for `jwtVerificationError` OR `nonExistentUser`, false otherwise
   - `toString()` → `'ApiException($action): ${message ?? ""}'`
   - `ApiErrorActions` class with 4 exact string constants:
     - `parameterInvalid = 'ParameterInvalid'`
     - `invalidSignature = 'InvalidSignature'`
     - `jwtVerificationError = 'JWTVerificationError'`
     - `nonExistentUser = 'NonExistentUser'`

2. **`lib/core/network/endpoints.dart`** — `Endpoints` class with 25 `static const String` path constants sourced from `docs/api/api/api-reference.md` (e.g. `/api/v1/startup`, `/api/v1/sessions`, `/api/v2/search`, `/api/v1/articles`, etc.). Only the constants listed in the brief — no path-template constants (YAGNI).

3. **`test/core/network/api_exception_test.dart`** — TDD test with 2 cases (auth-error true / non-auth false). Test text was taken verbatim from the brief; the two `ApiException.fromAction(...)` call sites were line-wrapped to respect the project's ≤80-char line-length rule (CLAUDE.md). Semantics unchanged.

## TDD evidence

### RED (Step 2)

Command: `flutter test test/core/network/api_exception_test.dart`

Exit code: **1**

Key output (proves RED is for "ApiException undefined", not a syntax error in the test):
```
test/core/network/api_exception_test.dart:2:8: Error: Error when reading 'lib/core/network/api_exception.dart': No such file or directory
  import 'package:jade/core/network/api_exception.dart';
       ^
test/core/network/api_exception_test.dart:6:15: Error: Undefined name 'ApiException'.
  final e = ApiException.fromAction(
              ^^^^^^^^^^^^
test/core/network/api_exception_test.dart:7:7: Error: Undefined name 'ApiErrorActions'.
  ApiErrorActions.jwtVerificationError,
      ^^^^^^^^^^^^^^^
...
Failed to load ".../api_exception_test.dart": Compilation failed
00:00 +0 -1: Some tests failed.
```

### GREEN (Step 4)

Command: `flutter test test/core/network/api_exception_test.dart`

Exit code: **0**

Full output (pristine, no warnings):
```
00:00 +0: loading /Users/luxcis/data/workspace/Flutter/Jdb_Flutter/test/core/network/api_exception_test.dart
00:00 +0: ApiException 携带 action 与 message
00:00 +1: 非鉴权 action 的 isAuthError 为 false
00:00 +2: All tests passed!
```

`flutter analyze` on the 3 new files: **No issues found! (ran in 0.7s)**

## Files changed

- `lib/core/network/api_exception.dart` (new)
- `lib/core/network/endpoints.dart` (new)
- `test/core/network/api_exception_test.dart` (new)

3 files changed, 83 insertions(+).

## Commit

- Short SHA: **`b71927d`**
- Subject: `feat(core/network): add ApiException and Endpoints constants`
- Branch: `feature/phase0-foundation`
- Staged files: exactly the 3 listed above (specific paths, no `git add -A`). `.superpowers/` left untracked.
- Not pushed (per task instructions).

## Self-review checklist

- [x] `isAuthError` returns true for `JWTVerificationError` AND `NonExistentUser`; false otherwise (verified by both tests).
- [x] The 4 `ApiErrorActions` constants are exact string values (`ParameterInvalid`, `InvalidSignature`, `JWTVerificationError`, `NonExistentUser`).
- [x] `ApiException` implements `Exception`, carries `action` + `message`, has `fromAction` factory.
- [x] `Endpoints` path constants match the brief exactly; no path-template constants (e.g. `/api/v4/movies/{movie_id}`) added — YAGNI.
- [x] TDD RED + GREEN captured with pristine output.
- [x] `flutter analyze` clean on all 3 new files.

## Concerns

None. Implementation is verbatim per the brief; the only deviation is formatting the two `fromAction(...)` call sites across multiple lines to comply with the project's 80-char line-length rule (CLAUDE.md / `analysis_options.yaml`). This is a pure formatting change — semantics and assertions are identical to the brief, and `flutter analyze` reports no issues.
