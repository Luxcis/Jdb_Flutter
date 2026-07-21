# 移动端图片解密说明

## 现象

`/api/v1/movies/latest`、`/api/v1/movies/recommend` 等接口返回的封面地址通常长这样：

```text
https://tp.spfcas.com/rhe951l4q/covers/xw/XWYgG.jpg
```

这个地址看起来是普通 `.jpg`，但直接在浏览器打开时无法按正常图片展示。后来用 `startup` 接口里的
`web_image_prefix` 把路径改写到 Web
CDN，例如 `https://c0.jdbstatic.com/covers/xw/XWYgG.jpg`，虽然可以显示，但图片右下角会带水印。

官方 APK 客户端里看到的是无水印图片，说明客户端没有依赖 Web CDN 的水印图，而是在本地对移动端 CDN
返回的字节做了解密。

## 结论

移动端 CDN 的图片 payload 使用了一个非常轻量的按字节 XOR 加密格式：

1. 只对图片后缀生效：`.jpg`、`.jpeg`、`.png`、`.webp`、`.gif`。
2. 下载到的第一个字节是密钥。
3. 如果第一个字节小于 `0xff`，客户端会丢弃这个字节。
4. 后续每一个字节都与这个密钥做 XOR。
5. XOR 后得到的内容才是真正的 JPEG/PNG/WebP/GIF 文件。
6. 如果第一个字节已经是 `0xff`，说明它本来就是普通 JPEG，客户端直接原样使用。

用公式表示就是：

```text
key = encrypted[0]
plain = encrypted[1:] 每个字节 XOR key
```

示例地址 `https://tp.spfcas.com/rhe951l4q/covers/xw/XWYgG.jpg` 的第一字节是 `0x3d`。把后续字节全部与
`0x3d` 异或后，开头会还原为标准 JPEG/JFIF 头：

```text
ff d8 ff e0 00 10 4a 46 49 46 00
```

## 逆向位置

算法位于 Flutter AOT 代码里的缓存下载流程，而不是 Android 系统图片组件，也不是 `libflutter.so` 引擎补丁。

关键位置：

```text
out_blutter/asm/flutter_cache_manager/src/web/web_helper.dart
```

对应逻辑在 `_saveFileAndPostUpdates` 的响应流处理里。反编译结果显示，客户端下载文件时会把 HTTP
response stream 经过一个 `Stream.map` 闭包。这个闭包负责判断 URL 后缀、读取第一字节作为密钥、丢弃密钥字节，并对后续
chunk 做 XOR。

这也解释了为什么 API 里的移动端 CDN 链接不能直接给 `<img>` 使用：浏览器只会按普通 JPEG 解码，不会执行
APK 里的缓存层解密逻辑。

## 与 web_image_prefix 的关系

`web_image_prefix` 是 Web 展示用 CDN 前缀。把移动端路径改写成 Web CDN 地址，能绕过加密问题，但拿到的是
Web 侧图片资源。

两者区别如下：

| 方式                                 | 结果              | 说明                |
|------------------------------------|-----------------|-------------------|
| 直接打开 `tp.spfcas.com/rhe951l4q/...` | 不能正常显示          | payload 被 XOR 处理过 |
| 改写到 `web_image_prefix`             | 可以显示，但可能有水印     | 使用 Web 展示资源       |
| 下载移动端 CDN 并执行 XOR 解密               | 可以得到 APK 同款无水印图 | 复现官方客户端逻辑         |

因此，正确复现官方 APK 的图片展示，应优先使用移动端 CDN 原始链接并执行本地解密，而不是把地址改写到 Web
CDN。

## 脚本用法

解密脚本在同目录：

```text
docs/security/images/jdb_image_decrypt.py
```

保存解密后的图片：

```bash
python3 docs/security/images/jdb_image_decrypt.py \
  'https://tp.spfcas.com/rhe951l4q/covers/xw/XWYgG.jpg' \
  /tmp/XWYgG_decrypted.jpg
```

查看图片头和 XOR 密钥证据：

```bash
python3 docs/security/images/jdb_image_decrypt.py \
  --inspect-header \
  'https://tp.spfcas.com/rhe951l4q/covers/xw/XWYgG.jpg'
```

脚本默认执行移动端 CDN 解密。如果只是想对比 Web CDN 水印图，可以显式使用 fallback：

```bash
python3 docs/security/images/jdb_image_decrypt.py \
  --web-fallback \
  'https://tp.spfcas.com/rhe951l4q/covers/xw/XWYgG.jpg' \
  /tmp/XWYgG_web.jpg
```

## Python 核心逻辑

脚本里的核心函数很短：

```python
def decrypt_mobile_image_bytes(data: bytes) -> bytes:
    if not data:
        raise ValueError("empty image payload")

    key = data[0]
    if key >= 0xFF:
        return data

    return bytes(byte ^ key for byte in data[1:])
```

这个函数只负责复现 APK 的解密步骤。下载、文件保存、图片格式校验都在脚本的外层函数里完成。

## 验证方式

单元测试覆盖了三个关键情况：

1. 移动端加密 payload：丢弃首字节并 XOR 还原。
2. 普通 JPEG：首字节是 `0xff` 时原样返回。
3. 空响应：抛出错误，避免写出无效图片。

运行测试：

```bash
python3 -m unittest docs/security/images/test_jdb_image_decrypt.py
```
