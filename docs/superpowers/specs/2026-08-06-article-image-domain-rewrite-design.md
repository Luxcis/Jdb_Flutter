# 资讯正文图片域名替换为 imageDomain 设计

## 目标

修改 `resolveArticleImageUrls`，把资讯正文中图片地址的域名统一替换为接口返回的
`imageDomain`，使正文图片走移动端 XOR 加密 CDN，经 `JdbImageCacheManager`
解密后正确显示（解决 c0.jdbstatic.com 明文图片被解密器误 XOR 导致解码失败的问题）。

## 已确认需求

- `imageDomain` 非空时，正文中所有网络图片地址改写为 `imageDomain + 原路径(含 query)`：
  - 绝对 http/https：`https://c0.jdbstatic.com/articles/x.jpg` →
    `imageDomain + /articles/x.jpg`（替换 origin，保留路径与 query）；
  - 协议相对：`//cdn.x.com/a.jpg` → `imageDomain + /a.jpg`；
  - 相对路径：`/a.jpg`、`a.jpg` → `imageDomain + /a.jpg`（保持现状语义）。
- src 已以 `imageDomain` 开头时不改写（幂等，避免 `/rhe951l4q` 之类前缀重复）。
- `data:`、`asset:`、`file:` 等非网络 src 保持不变。
- `imageDomain` 为空时原样返回 content。

## 实现

`lib/features/articles/screens/article_detail_screen.dart` 的
`resolveArticleImageUrls`：

- 用 `Uri.tryParse` 解析 src；
- 协议相对（`src.startsWith('//')`）与 http/https：取 `uri.path`（+`?uri.query`）
  拼到规范化后的 `base`（`//` 开头补 `https:`）之后；
- 其余有 scheme 的（data:/asset: 等）原样返回；
- 相对路径沿用现有拼接逻辑。

## 测试与验收

- 更新 `test/features/articles/article_detail_screen_test.dart`：
  - `//cdn.x.com/a.jpg` 现期望改为 `imageDomain + /a.jpg`；
  - `HTTPS://...` 现期望改为规范化的 `imageDomain + /a.jpg`；
  - 新增：c0.jdbstatic 绝对地址替换、query 保留、幂等不变、data/asset 不变、
    imageDomain 为空不变。
- `flutter analyze` 无告警；相关测试通过；真机确认正文图片可正常显示且模糊跟随。

## 成功标准

- 正文图片 URL 域名统一为 `imageDomain`，图片经解密通道正常渲染。
- 相对地址、协议相对地址、绝对地址行为一致；无重复前缀。
