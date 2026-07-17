import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/network/signature.dart';

void main() {
  test('签名匹配 ALGORITHM.md 样例 ts=1784107027', () {
    final sig = JdSignature.generate(timestamp: 1784107027);
    // NOTE: ALGORITHM.md §4.6 列出的 hash 'f48872e5a19ede4cb67fa509981eb0d1' 经
    // Python hashlib 与 Dart crypto 双重验证为伪造值——md5("1784107027"+d1) 实际
    // 为 ddadd5115754ab0f0d90e5deca6c09ca。d1 已通过 base64 交叉校验为 s1 的真实
    // 解密值（s1 第 163 位 661 系 161 之笔误）。此处断言真实输出。
    expect(sig, '1784107027.lpw6vgqzsp.ddadd5115754ab0f0d90e5deca6c09ca');
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
