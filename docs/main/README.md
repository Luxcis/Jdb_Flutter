# JavDB Reverse Engineering Docs

本文档目录按业务主题拆分，避免把 API、签名、域名和图片处理逻辑混在同一个目录里。

## 目录结构

| 目录                    | 内容                        |
|-----------------------|---------------------------|
| `api/`                | API 规范、接口说明、请求示例          |
| `security/signature/` | `jdsignature` 请求签名算法与生成脚本 |
| `security/domains/`   | 备用 API 域名解密和域名切换说明        |
| `security/images/`    | 移动端 CDN 图片解密算法、脚本和测试      |

## 快速入口

| 文件                                                                                       | 说明                       |
|------------------------------------------------------------------------------------------|--------------------------|
| [api/api-reference.md](api/api-reference.md)                                             | API 接口说明，基于 OpenAPI 规范整理 |
| [api/jdb_api_openapi.json](api/jdb_api_openapi.json)                                     | OpenAPI 3.0.3 规范文件       |
| [security/signature/ALGORITHM.md](security/signature/ALGORITHM.md)                       | API 请求签名算法说明             |
| [security/signature/gen_signature.py](security/signature/gen_signature.py)               | 签名生成脚本                   |
| [security/domains/backup-domains.md](security/domains/backup-domains.md)                 | 备用域名解密说明                 |
| [security/domains/decrypt_backup_domains.py](security/domains/decrypt_backup_domains.py) | 备用域名解密脚本                 |
| [security/images/image-decryption.md](security/images/image-decryption.md)               | 移动端图片解密说明                |
| [security/images/jdb_image_decrypt.py](security/images/jdb_image_decrypt.py)             | 移动端 CDN 图片解密脚本           |

## 当前结论

API 返回的 `tp.spfcas.com/rhe951l4q/...` 图片链接不是普通前端可以直接展示的图片文件。官方 APK
在下载图片后，会在 Flutter 缓存层对响应字节做一次轻量解密，再把解密后的 JPEG/PNG/WebP/GIF 写入本地缓存。

如果把移动端路径改写到 `web_image_prefix`，例如 `https://c0.jdbstatic.com/`，浏览器确实能显示图片，但那是
Web 侧可展示资源，可能带有右下角水印。官方 APK 的无水印图来自移动端 CDN 原始 payload 解密，而不是简单替换域名。
