### Task 3: JdSignature 签名算法

**Files:**
- Create: `lib/core/network/signature.dart`
- Test: `test/core/network/signature_test.dart`

**Interfaces:**
- Produces: `String JdSignature.generate({int? timestamp})`，格式 `{ts}.{d2}.{md5(ts+d1)}`。

- [ ] **Step 1: 写失败测试（对照 ALGORITHM.md §4.6 样例）**

```dart
// test/core/network/signature_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/signature.dart';

void main() {
  test('签名匹配 ALGORITHM.md 样例 ts=1784107027', () {
    final sig = JdSignature.generate(timestamp: 1784107027);
    expect(sig, '1784107027.lpw6vgqzsp.f48872e5a19ede4cb67fa509981eb0d1');
  });

  test('签名格式为 timestamp.d2.md5hash', () {
    final sig = JdSignature.generate(timestamp: 1784107027);
    final parts = sig.split('.');
    expect(parts.length, 3);
    expect(parts[0], '1784107027');
    expect(parts[1], 'lpw6vgqzsp');
    expect(parts[2].length, 32); // md5 hex
  });

  test('不同 timestamp 产生不同签名', () {
    final a = JdSignature.generate(timestamp: 1784107027);
    final b = JdSignature.generate(timestamp: 1784107028);
    expect(a == b, isFalse);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/network/signature_test.dart`
Expected: FAIL（`JdSignature` 未定义）。

- [ ] **Step 3: 实现**

```dart
// lib/core/network/signature.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// 生成 JavDB API 请求头 jdsignature。
///
/// 格式：`{timestamp}.{d2}.{md5(timestamp + d1)}`，常量取自
/// docs/api/signature/ALGORITHM.md §4.5（已解密）。
class JdSignature {
  const JdSignature._();

  static const String _d1 =
      '71cf27bb3c0bcdf207b64abecddc970098c7421ee7203b9cdae54478478a199e7d5a6e1a57691123c1a931c057842fb73ba3b3c83bcd69c17ccf174081e3d8aa';
  static const String _d2 = 'lpw6vgqzsp';

  /// 生成签名。[timestamp] 为 Unix 秒；测试时注入确定性时间戳。
  static String generate({int? timestamp}) {
    final ts = timestamp ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final hash = md5.convert(utf8.encode('$ts$_d1'));
    return '$ts.$_d2.${hash.toString()}';
  }
}
```

- [ ] **Step 4: 运行测试通过**

Run: `flutter test test/core/network/signature_test.dart`
Expected: PASS（3 个用例）。

- [ ] **Step 5: Commit**

```bash
git add lib/core/network/signature.dart test/core/network/signature_test.dart
git commit -m "feat(core/network): implement jdsignature generation"
```

---

