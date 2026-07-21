# backup_domains_data 解密方法

## 概述

`backup_domains_data` 是 startup API（`GET /api/v1/startup`）返回的加密字段，包含 JavDB 的备用域名配置。客户端在收到此数据后解密为 `DomainEntity`，用于动态切换 API 端点。

## 逆向来源

解密逻辑位于反编译的 `splash_page.dart`（地址 `0x7e0a3c`），流程如下：

```
┌─────────────────────────────────────────────────────────┐
│               startup API 响应                           │
│  { ..., "backup_domains_data": "<base64加密数据>" }      │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  Step 1: 派生 AES 密钥 (16 bytes)                       │
│                                                         │
│  accessKey = getKey()           // SpUtil 读取 "accessKey"│
│           = "30820"             // APK 证书 DER 前5字符   │
│                                                         │
│  aes_key = getDecryptString(s1_blob, accessKey)          │
│          = "px0wbsdzxg7f6br9"                           │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  Step 2: 派生 AES IV (16 bytes)                         │
│                                                         │
│  aes_iv = getDecryptString(s2_blob, "astarte")           │
│         = "qqzy7jvk9jlaxhlc"                            │
│                                                         │
│  注意：IV 使用固定字符串 "astarte" 作为派生密钥，       │
│        而非 accessKey                                   │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  Step 3: AES-CBC 解密                                   │
│                                                         │
│  ciphertext = base64_decode(backup_domains_data)        │
│  plaintext  = AES-CBC-Decrypt(                          │
│      ciphertext,                                        │
│      key  = UTF8(aes_key),    // "px0wbsdzxg7f6br9"    │
│      iv   = UTF8(aes_iv),     // "qqzy7jvk9jlaxhlc"    │
│      mode = CBC,                                        │
│      padding = PKCS7                                    │
│  )                                                      │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  Step 4: JSON 解析                                      │
│                                                         │
│  DomainEntity = JSON.parse(plaintext)                   │
│                                                         │
│  字段：apiDomains, backupUrls, unblockedWebDomain,      │
│        permanentWebDomain, unblockAppDomain,             │
│        permanentAppDomain, imageEndpoint                │
└─────────────────────────────────────────────────────────┘
```

## getDecryptString 算法

这是 Dart 层的一个通用解密函数（`common_tools.dart` 地址 `0x58d4bc`），在签名生成和域名解密中均有使用。

**输入：** `(b64_blob: string, key: string)`

**步骤：**

1. 计算 `md5_hex = MD5(key)`，得到 32 字符的十六进制字符串
2. Base64 解码 `b64_blob` → JSON 整数数组 `arr`
3. 对每个元素执行减法运算：
   ```
   result[i] = arr[i] - ASCII(md5_hex[min(i, 31)])
   ```
   **关键细节：**
   - 是**减法**而非异或
   - 索引使用 `min(i, 31)` **截断**而非 `i % 32` 取模
   - 即超过 31 的索引全部使用 MD5 的第 32 个字符（索引 31）
4. 将 `result` 字节按 Latin-1 解码 → 得到一个 base64 编码的字符串
5. Base64 解码该字符串 → 得到最终明文

**注意：** 这是一个"双重 base64"设计——外层 base64 包裹 JSON 整数数组，内层 base64 包裹最终结果。

## 硬编码常量

| 常量 | 值 | 来源 |
|------|-----|------|
| `secret` | `"30820"` | APK 签名证书 DER 前 5 字符 |
| `s1_blob` | 24 元素 base64 JSON 数组 | `splash_page.dart` 0x7e0ad8 |
| `s2_blob` | 24 元素 base64 JSON 数组 | `splash_page.dart` 0x7e0b00 |
| `iv_key` | `"astarte"` | Flutter 应用名（Astarte = JavDB）|

## 解密结果示例

```json
{
  "apiDomains": [
    "https://apidd.spthgb.com",
    "https://apidd.czssdgz.com"
  ],
  "backupUrls": [
    "https://app-1392310394.cos.ap-guangzhou.myqcloud.com/ds_store"
  ],
  "unblockedWebDomain": "https://javdb573.com",
  "permanentWebDomain": "https://javdb.com",
  "unblockAppDomain": "https://app.javdb573.com",
  "permanentAppDomain": "https://jav.app",
  "imageEndpoint": "https://tp.spfcas.com"
}
```

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `apiDomains` | `string[]` | 备用 API 域名列表，客户端可切换 |
| `backupUrls` | `string[]` | 云端配置文件 URL（腾讯云 COS） |
| `unblockedWebDomain` | `string` | 未被封锁的 Web 官网域名 |
| `permanentWebDomain` | `string` | 永久 Web 官网域名 |
| `unblockAppDomain` | `string` | 未被封锁的 App 下载域名 |
| `permanentAppDomain` | `string` | 永久 App 下载域名 |
| `imageEndpoint` | `string` | 图片/封面 CDN 端点 |
