import 'dart:convert';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:jade/core/models/startup.dart';

/// 解密 startup API 返回的 backup_domains_data 字段。
///
/// 解密流程参见 docs/api/signature/backup-domains.md，常量
/// [_aesKey] / [_aesIv] 已通过 getDecryptString 提前解密。
class BackupDomainsDecryptor {
  const BackupDomainsDecryptor._();

  static const String _aesKey = 'px0wbsdzxg7f6br9';
  static const String _aesIv = 'qqzy7jvk9jlaxhlc';

  /// 解密 [backupDomainsData] 并返回 [BackupDomains]。
  ///
  /// [backupDomainsData] 为 startup API 返回的原始 base64 密文。
  static BackupDomains decrypt(String backupDomainsData) {
    final key = enc.Key.fromUtf8(_aesKey);
    final iv = enc.IV.fromUtf8(_aesIv);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final plaintext = encrypter.decrypt64(backupDomainsData, iv: iv);
    return BackupDomains.fromJson(
      json.decode(plaintext) as Map<String, dynamic>,
    );
  }
}
