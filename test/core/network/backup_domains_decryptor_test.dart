import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/network/backup_domains_decryptor.dart';

/// 测试密文来自 docs/api/signature/decrypt_backup_domains.py 中的示例数据。
const _testCiphertext =
    'JCxJQTR1DerICeuy4lmmWJuj2sRqgbDdvL2Nru5I6BmGb+GmAKKAUbjeLL1r+rFe'
    'Oxq+Kb3g2MOSXYpvd9dA7Pds+G6brFTtRy7EQ0s4DkIaUfAzoKgMWldPRI/0IvUj'
    'OvVkn1t0/nUIEz2LTWmcKx5sj3BVtIV5XEiRtS8fUGvVSddw6Fy7g9nJ/iN5OxFC'
    'ypbRPK0dd6+09Vx3ALU/9kI39VeBlNZE7/Vjnr2nc0MZg3PIZHCt9dlldO9uS7GM'
    'LU+LHXFq29VbyGGkXxlOuO+dE4ejYK1CJ9Qx14FuR1xWx3p8rOHo1INDE7LmqgZy'
    '/3vDlRY8hHbdDr81tKWBAS/PXcOakVZGNuEiOf6OKtQR9J3M44MUStw+k5AZ9jh0'
    'KhblvYeTdA79l1b+byubUqyDLP5XiEkyT2yQ8JTB/wHfH6Otg5/5NoI22nODaQjK'
    'UaFDDnzr0S2Vwbp0uu68GAov458mHuuIUleBSI4TGqA=';

void main() {
  group('BackupDomainsDecryptor', () {
    test('解密测试密文，匹配 Python 脚本预期输出', () {
      final result = BackupDomainsDecryptor.decrypt(_testCiphertext);

      expect(result.apiDomains, [
        'https://apidd.spthgb.com',
        'https://apidd.czssdgz.com',
      ]);
      expect(result.backupUrls, [
        'https://app-1392310394.cos.ap-guangzhou.myqcloud.com/ds_store',
      ]);
      expect(result.unblockedWebDomain, 'https://javdb573.com');
      expect(result.permanentWebDomain, 'https://javdb.com');
      expect(result.unblockAppDomain, 'https://app.javdb573.com');
      expect(result.permanentAppDomain, 'https://jav.app');
      expect(result.imageEndpoint, 'https://tp.spfcas.com');
    });

    test('解密结果字段类型正确', () {
      final result = BackupDomainsDecryptor.decrypt(_testCiphertext);

      expect(result, isA<BackupDomains>());
      expect(result.apiDomains, isA<List<String>>());
      expect(result.backupUrls, isA<List<String>>());
      expect(result.apiDomains.isNotEmpty, isTrue);
    });

    test('非法 base64 输入抛出异常', () {
      expect(
        () => BackupDomainsDecryptor.decrypt('!!!invalid!!!'),
        throwsA(isA<FormatException>()),
      );
    });

    test('AES key 和 IV 常量与 Python 脚本一致，解密成功', () {
      // 解密成功即证明 _aesKey / _aesIv 常量值正确。
      final result = BackupDomainsDecryptor.decrypt(_testCiphertext);
      expect(result.apiDomains.length, 2);
      expect(result.unblockedWebDomain, isNotEmpty);
    });
  });
}
