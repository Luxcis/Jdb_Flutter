# 签名算法实现说明 (ALGORITHM.md)

## 1. 概述

JavDB App 的所有 API 请求必须携带 `jdsignature` 请求头，否则服务器拒绝请求。该签名基于时间戳 +
预解密常量 + MD5 哈希生成，核心密钥通过 JNI 从 `libsecurity.so` 获取。

## 2. 涉及的组件

| 组件                   | 位置                                  | 作用                                      |
|----------------------|-------------------------------------|-----------------------------------------|
| `libsecurity.so`     | `lib/arm64-v8a/`                    | JNI `getSecret()` 返回 5 字符密钥             |
| `libapp.so`          | `lib/arm64-v8a/`                    | Dart AOT 代码，含两个加密常量 s1/s2               |
| `SecurityUtil.smali` | `smali/xxx/pornhub/fuck/`           | Java 层 JNI 声明                           |
| `common_tools.dart`  | `out_blutter/asm/astarte/utils/`    | `getSignature()` 和 `getDecryptString()` |
| `common_utils.dart`  | `out_blutter/asm/astarte/utils/`    | `getKey()` 从 SpUtil/native 获取密钥         |
| `encrypt_util.dart`  | `out_blutter/asm/common_utils/src/` | `encodeMd5()` 和 `decodeBase64()`        |
| `intercept.dart`     | `out_blutter/asm/astarte/net/`      | `AuthInterceptor` 注入签名头                 |

## 3. 签名生成流程

```
┌─────────────────────────────────────────────────────────────────┐
│  getSignature()  (common_tools.dart @ 0x58d2bc)                │
│                                                                 │
│  1. key = getKey()                    // "30820"               │
│  2. d1 = getDecryptString(s1, key)    // base64 编码的 hex 串   │
│  3. d2 = getDecryptString(s2, key)    // base64 编码的短串      │
│  4. timestamp = floor(now_micros / 1000000)  // Unix 秒         │
│  5. md5_hash = encodeMd5(timestamp + d1)                       │
│  6. return "$timestamp.$d2.$md5_hash"                          │
│                                                                 │
│  注意: d1 和 d2 在拼入签名前经过 base64 decode                  │
│  最终签名格式: "1784107027.lpw6vgqzsp.f48872e5a19ede4cb67fa509981eb0d1"
└─────────────────────────────────────────────────────────────────┘
```

## 4. 各步骤详解

### 4.1 获取密钥 — `getKey()`

**位置**: `common_utils.dart @ 0x58d84c`

```
1. 检查 SpUtil.getString("accessKey", defValue: "")
2. 若已有缓存值 → 直接返回（避免重复 JNI 调用）
3. 若为空 → 调用 MethodChannel "handleAndroidChannel" 的 "getIKey" 方法
4. "getIKey" 触发 Java 层 SecurityUtil.getSecret()（JNI native 方法）
5. 将返回值存入 SpUtil "accessKey" 键
6. 返回该值
```

### 4.2 Native 层 — `getSecret()`

**位置**: `libsecurity.so @ 0x1950`（函数大小 1064 字节）

```c
// 伪代码还原（基于 ARM64 反汇编）
jstring Java_xxx_pornhub_fuck_SecurityUtil_getSecret(JNIEnv* env, jclass cls) {
    // 1. 获取 ActivityThread.currentApplication()
    jclass activityThread = FindClass("android/app/ActivityThread");
    jmethodID currentApp = GetStaticMethodID(activityThread, "currentApplication", "()Landroid/app/Application;");
    jobject app = CallStaticObjectMethod(activityThread, currentApp);

    // 2. 获取 PackageManager
    jmethodID getPM = GetMethodID(app_class, "getPackageManager", "()Landroid/content/pm/PackageManager;");
    jobject pm = CallObjectMethod(app, getPM);

    // 3. 获取包名
    jmethodID getPackageName = GetMethodID(app_class, "getPackageName", "()Ljava/lang/String;");
    jstring packageName = CallObjectMethod(app, getPackageName);

    // 4. 获取 PackageInfo（带 GET_SIGNATURES flag = 0x40）
    jmethodID getPackageInfo = GetMethodID(pm_class, "getPackageInfo", "(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;");
    jobject packageInfo = CallObjectMethod(pm, getPackageInfo, packageName, 0x40);

    // 5. 获取 signatures 数组
    jfieldID signaturesField = GetFieldID(packageInfo_class, "signatures", "[Landroid/content/pm/Signature;");
    jobjectArray signatures = GetObjectField(packageInfo, signaturesField);

    // 6. 取第一个签名
    jobject signature = GetObjectArrayElement(signatures, 0);

    // 7. 调用 Signature.toCharsString() → 返回 DER 证书的 hex 字符串
    jmethodID toCharsString = GetMethodID(signature_class, "toCharsString", "()Ljava/lang/String;");
    jstring hexStr = CallObjectMethod(signature, toCharsString);

    // 8. 用 strncpy 复制前 5 个字符
    char buf[6] = {0};
    const char* raw = GetStringUTFChars(hexStr);
    strncpy(buf, raw, 5);   // <--- 关键：只取前 5 个字符

    // 9. 创建新 jstring 返回
    return NewStringUTF(buf);  // "30820"
}
```

**汇编关键证据**:

- `0x1b08: mov w4, #0x40` — GET_SIGNATURES flag
- `0x1cc4: mov w2, #0x5` — strncpy 长度 = 5
- `0x1cd0: bl strncpy` — 复制前 5 字符

**为何是 "30820"**:
DER 编码的 X.509 证书以 `SEQUENCE` (0x30) 开头，后跟长度字段 `0x82`（2字节长度），所以所有 DER 证书的
hex 都以 `3082` 开头。第 5 个字符取决于证书总长度。本 APK 的证书 hex 前 5 位恰好是 `30820`。

### 4.3 解密函数 — `getDecryptString()`

**位置**: `common_tools.dart @ 0x58d4bc`

```dart
// 伪代码还原
String getDecryptString(String b64Encrypted, String key) {
  // 1. 计算 key 的 MD5（返回 32 字符小写 hex 字符串）
  String md5Hex = EncryptUtil.encodeMd5(key); // md5("30820") = "da97c8240e2ad99a2d331eed95c411f5"

  // 2. Base64 解码 b64Encrypted → JSON 数组
  String jsonStr = EncryptUtil.decodeBase64(b64Encrypted); // "[178,219,127,161,...]"
  List<int> encrypted = json.decode(jsonStr);

  // 3. 逐元素减法：arr[i] - md5Hex[min(i, 31)]
  //    注意：使用 min(i, 31) 作为索引，即超过 32 字符后都用第 31 位
  List<int> result = [];
  for (int i = 0; i < encrypted.length; i++) {
    int idx = min(i, md5Hex.length - 1); // min(i, 31)
    int keyChar = md5Hex.codeUnitAt(idx);
    result.add(encrypted[i] - keyChar); // 减法，不是 XOR
  }

  // 4. 将 code units 转为字符串
  String intermediate = String.fromCharCodes(result);

  // 5. Base64 解码得到最终明文
  return EncryptUtil.decodeBase64(intermediate);
}
```

**汇编关键证据**:

- `0x58d4dc: bl encodeMd5` — 计算 MD5
- `0x58d4e8: bl decodeBase64` — Base64 解码
- `0x58d53c: ldur w0, [x1, #7]` — 读取字符串长度
- `0x58d548: sub x3, x2, #1` — `len - 1`（用于 min 边界）
- `0x58d5cc: cmp x8, x3` — 比较索引与边界
- `0x58d5dc: mov x9, x8` / `0x58d5e4: mov x9, x6` — 取 min(i, len-1)
- `0x58d6b0: sub x6, x5, x4` — **减法指令**（result = arr[i] - md5_char）

### 4.4 加密常量 s1 和 s2

两个 base64 编码的 JSON 整数数组，硬编码在 `libapp.so` 的 Dart 对象池中。

**提取方式**:

```bash
strings lib/arm64-v8a/libapp.so | grep '^WzE3OC'  # s1
strings lib/arm64-v8a/libapp.so | grep '^WzE5OC'  # s2
```

**s1**（172 个元素，解密后为 128 字符 hex 字符串的 base64 编码）:

```
WzE3OCwyMTksMTI3LDE2MSwxODksMTYyLDEyMywxMDMsMTM3LDIxMCwxMjMsMjE5LDE4OSwxNzksMTIzLDIwMiwxMzksMTUwLDEzMywxNjAsMTI2LDIwNywxNjYsMTUxLDE0NiwxNTksMTg4LDEwMCwxMzgsMTM2LDE3NiwxNjEsMTQyLDEwMywxMzUsMTYwLDE0MiwxNzUsMTYwLDEwNCwxMzAsMTIxLDExOCwxMDYsMTMyLDEyNCwxMzAsMTA0LDEzMSwxMjEsMTI2LDE3MywxNDMsMTQwLDEzOCwxMDQsMTMwLDE1OSwxMTgsMTc1LDE0MiwxNTksMTYxLDE1OSwxNDMsMTI0LDEyMywxNjEsMTMxLDEzNywxMzQsMTAxLDEzMSwxNzUsMTU2LDEwMSwxMzEsMTc1LDE1NywxNTcsMTMwLDEzNywxNjAsMTA2LDE0MywxMzcsMTUzLDE2MCwxMzEsMTQwLDEyMiwxMDMsMTQzLDEzNywxMjMsMTU3LDEzMSwxMzcsMTUyLDEwMywxMzIsMTM3LDEyMiwxNzMsMTMwLDE1OSwxMzEsMTU5LDEzMCwxNDAsMTIyLDEwNiwxMzAsMTc1LDEyMywxNTksMTMwLDEyMSwxMzgsMTA0LDEzMiwxMjEsMTM0LDE3NCwxNDMsMTYyLDEyNiwxMDQsMTMwLDEwMywxMjcsMTU3LDEzMCwxMDMsMTI2LDE3NSwxNDIsMTc1LDE1NiwxNzUsMTQyLDE2MiwxMzEsMTYwLDEzMSwxNTksMTYxLDE1OSwxMzAsMTM3LDE1MywxNTksMTQyLDEwMywxNDIsMTczLDEzMSwxNzUsMTM0LDE3MiwxMzIsMTIxLDEyMyw2NjEsMTMwLDEwMywxMzQsMTA1LDE0MiwxNDAsMTIyLDExNF0=
```

**s2**（16 个元素，解密后为 "lpw6vgqzsp" 的 base64 编码）:

```
WzE5OCwxNjksMTIzLDEwNiwxNzcsMTY2LDE0MCwxNjIsMTQ3LDE4OSwxNjIsMjE5LDE5OSwxMjIsMTE4LDE1OF0=
```

### 4.5 最终解密结果

| 常量 | 解密中间值（base64）                                    | 最终值                                                                                                                                |
|----|--------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| d1 | `NzFjZjI3YmIzYzBiY2RmMjA3...eHJlNTQ0Nzg0Nzhh...` | `71cf27bb3c0bcdf207b64abecddc970098c7421ee7203b9cdae54478478a199e7d5a6e1a57691123c1a931c057842fb73ba3b3c83bcd69c17ccf174081e3d8aa` |
| d2 | `bHB3NnZncXpzcA==`                               | `lpw6vgqzsp`                                                                                                                       |

### 4.6 签名组装

```python
timestamp = 1784107027  # 示例
md5_input = "1784107027" + "71cf27bb3c0bcdf207b64abecddc970098c7421ee7203b9cdae54478478a199e7d5a6e1a57691123c1a931c057842fb73ba3b3c83bcd69c17ccf174081e3d8aa"
md5_hash = md5(md5_input) = "f48872e5a19ede4cb67fa509981eb0d1"
signature = "1784107027.lpw6vgqzsp.f48872e5a19ede4cb67fa509981eb0d1"
```

## 5. 完整 Python 实现

```python
import hashlib, time

# 硬编码常量（无需读取文件）
D1 = "71cf27bb3c0bcdf207b64abecddc970098c7421ee7203b9cdae54478478a199e7d5a6e1a57691123c1a931c057842fb73ba3b3c83bcd69c17ccf174081e3d8aa"
D2 = "lpw6vgqzsp"

def gen_signature():
    ts = int(time.time())
    md5_h = hashlib.md5((str(ts) + D1).encode()).hexdigest()
    return f"{ts}.{D2}.{md5_h}"
```

## 6. 从零复现的步骤

1. 用 apktool 解包 APK
2. 从 `original/META-INF/CERT.RSA` 提取 X.509 证书 DER bytes，转 hex，取前 5 字符得到 secret
3. 用 `strings` 从 `lib/arm64-v8a/libapp.so` 提取 s1 和 s2 两个 base64 字符串
4. 计算 `md5_hex = md5(secret).hexdigest()`
5. 对 s1/s2 各执行 `getDecryptString`（base64 decode → JSON array → 逐元素减 md5_hex → 转字符串 →
   base64 decode）
6. 得到 d1（128 字符 hex）和 d2（`lpw6vgqzsp`）
7. 签名 = `{timestamp}.{d2}.{md5(timestamp + d1)}`

## 7. 注意事项

- 签名中使用的减法（`sub`），不是 XOR（`eor`），这是逆向过程中的关键区分点
- MD5 使用的是 `crypto` 包的 `MD5` 实现，返回 32 字符小写 hex 字符串
- `encodeMd5` 内部流程：UTF-8 编码 → MD5 digest → Hex 编码 → 小写字符串
- 解密数组索引使用 `min(i, 31)`，超过 32 字符后重复使用最后一位
- d1 和 d2 都是双重编码（加密数组 → base64 字符串 → base64 解码 → 最终明文）
- `libsecurity.so` 中的 `getSecret()` 取证书 DER hex 前 5 字符，所以所有用相同证书签名的 APK 都会得到相同的
  `"30820"`
