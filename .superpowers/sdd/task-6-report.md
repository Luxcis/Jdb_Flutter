# Task 6 Report: 测试用 FakeAdapter

## Status: DONE_WITH_CONCERNS

## What was implemented

- `lib/core/network/testing/fake_adapter.dart` — `FakeAdapter` 实现 `HttpClientAdapter`，按 path 预设响应，记录请求历史
- `test/core/network/testing/fake_adapter_test.dart` — 2 个测试用例：路径匹配返回值、请求历史记录

## Files changed

| File | Action |
|---|---|
| `lib/core/network/testing/fake_adapter.dart` | Created (per brief verbatim) |
| `test/core/network/testing/fake_adapter_test.dart` | Created (adapted for dio 5.10.0) |

## TDD Evidence

### RED

The brief's test code (`resp.data['success']`) does not compile with dio 5.10.0 because `ResponseBody` has no `data` getter — it only exposes `stream`. This is a real API mismatch, not the expected "FakeAdapter not defined" error.

```
Error: The getter 'data' isn't defined for the type 'ResponseBody'.
```

### GREEN (after adaptation)

```
00:00 +0: FakeAdapter 按路径返回预设响应
00:00 +1: FakeAdapter 记录请求历史
00:00 +2: All tests passed!
```

2/2 passing, exit code 0, output pristine.

## Test adaptation details

The test imports `dart:convert` and uses a helper `_readBody(ResponseBody)` that reads the full `resp.stream`, decodes as UTF-8, and parses JSON. This is necessary because `ResponseBody.data` does not exist in dio 5.x — responses are stream-based.

## Concerns

1. **Dio 5.x API mismatch**: The brief's test assumed `ResponseBody.data` exists, but dio 5.10.0 uses `ResponseBody.stream`. The test was adapted with a `_readBody` helper. This is a known dio v4→v5 breaking change.

2. **TDD flow not pure**: The implementation file already existed with correct content from a prior run. Only the test needed fixing. Exact RED→GREEN sequence could not be captured as originally specified.

3. **Commit includes extra files**: The commit `fac7f50` also staged 17 `.superpowers/sdd/*` files that were previously unstaged. Only the two task files were intentionally added.

## Commit

```
fac7f50 test(core/network): add FakeAdapter for interceptor unit tests
```
