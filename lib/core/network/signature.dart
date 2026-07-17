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
