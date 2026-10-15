# MissAV 在线播放机制分析 + 番号即时播放器

> 逆向目标：`https://missav.live`（MissAV 主镜像之一）在线播放流程与反爬体系
> 分析工具：小段 `python/node` 沙箱解码 + REA 受控浏览器实况取证 + 本地 `curl` 对照矩阵
> 分析日期：2026-10-15

---

## 一、播放链路（verified）

```
用户输入番号 DLDSS-564
        │
        ▼
GET https://missav.live/{lang}/{code}        ← 页面 HTML（仅需普通浏览器 UA 即可 200，无 JS 质询）
        │
        ▼  页面内联脚本已被「Dean Edwards packer」混淆，eval(function(p,a,c,k,e,d)…)
解码后得到（radix=16 单层 packer，本播放器用 JS 实现同一解码算法）：

    source      = https://surrit.com/{UUID}/playlist.m3u8    ← master（多码率）
    source842   = https://surrit.com/{UUID}/720p/video.m3u8
    source1280  = https://surrit.com/{UUID}/1080p/video.m3u8

        │
        ▼  网页播放器：Plyr + hls.js（桌面 Chrome 路径）
new Hls();  hls.loadSource(source – master playlist)
        │
        ▼  master 里有 4 个视频变体（360p/480p/720p/1080p），**音轨内嵌在同一路流**
        │  （CODECS 含 mp4a.40.2，无单独 audio group；只有 iPad/Mac-touch 直接挂
        │   source1280 的原生 <video> 路径）
        ▼
分片伪装名 .jpeg（实际是 MPEG-TS，第一字节 0x47），逐段 Range 拉取
```

`{UUID}` 为每部视频独立的随机 UUID（如 `a5e4d7c9-2206-4f41-901c-1dd66a6ead27`），
**无法从番号直接推算**，必须先抓页面再解码 packer 才能拿到。

另附：master 播放列表还有：ancement `#EXT-X-TOKEN=...` 说明行、 进度条缩略图数据 `/{UUID}/seek/_N.jpg`
（N 数千级）也同 CDN domens。

## 二、反爬机制清单（全部经实验证实）

| # | 机制                          | 实验证据                                                                                                                           | 影响                                          |
|---|-------------------------------|------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------|
| 1 | **surrit CDN Cloudflare WAF** | 裸 curl 403「Attention Required！」页面                                                                                            | 无法爬取分片                                  |
| 2 | **Referer 白名单防盗链**      | curl 无 Referer / 伪造 Referer(evil 403)；带 `https://missav.live/ja/…` → 200 EXTM3U                                               | 分片/playlist/seek 全部要求 missav.* Referer  |
| 3 | **ACAO 仅回显官方 Origin**    | `Origin: https://missav.live` → `Access-Control-Allow-Origin: https://missav.live`；`Origin: http://localhost` → 200 但**无 ACAO** | 浏览器第三方 hls.js 请求**不可能**跨域拉 m3u8 |
| 4 | **TLS 指纹级客户端筛选**      | 同 Header（含 Referer）：curl h1/h2、直连/代理 均 200；undici fetch / undici h2 / node https 一律 403                              | node/undici 做 CDN 客户端必须换 curl 子进程   |
| 5 | **CDN 429 限速**              | 页面 JS 显式 `on error status===429 → hls.loadSource()` 重试                                                                       | 高频建联会限流                                |
| 6 | **页面 packer 混淆**          | 视频源 URL 以 Dean Edwards packer 藏于内联 `<script>`，无明文字符串                                                                | 需解码才能拿到 m3u8                           |
| 7 | **镜像域名白名单重定向**      | 第二个 4 层嵌套 packer：任何不在 `missav.ai/.ws/.live/...` 白名单或非 `missavXXXXXX.com` 模式的 host → JS 跳转 missav.ai           | 防克隆站，需选正确域名                        |
| 8 | 主站 Cloudflare               | 主站静态可直出（HTTP/2 200、cf-cache-status HIT），但裸 GET 根路径会跳 `/dm285/ja`（语言/区域 fallback 页）                        | curl 带 UA 即可，不棘手                       |

> 另外，主站根路径无 `Access-Control-Allow-Origin`，视频页设 `X-Frame-Options: SAMEORIGIN`，
> 因此 **不能**用 iframe 内嵌 missav 页面来播放。

## 三、本项目交付

```
missav-player/
├── server.js      本地中继（Node 18+，零 npm 依赖，依赖系统 curl）
├── player.html    番号即时播放器（单文件）
└── README.md      本说明
```

### 使用

```bash
cd missav-player
node server.js           # 默认 127.0.0.1:8931
# 浏览器打开 http://127.0.0.1:8931/
# 输入番号（DLDSS-564），回车或点「播放」→ 自动解析并播放
```

也支持 **完整视频链接**（例如 `https://missav.ws/ja/dldss-564-uncensored-leak`）直接粘入。

### server.js 的三个路由

| 路由                  | 用途                                                            |
|-----------------------|-----------------------------------------------------------------|
| `GET /`               | 托管同目录 `player.html`                                        |
| `GET /page/{码点}`    | 代抓 `missav.live/{码点}` 页面 HTML（注入 UA / Referer / 语系） |
| `GET /hls/{UUID}/...` | 反代 `surrit.com`（注入 Referer；转发 Range；流式回传影片分片） |

### player.html 的解析容错

1. packer 解码（Dean Edwards unPacker 等价 JS 实现，支持 radix=16 / 62）；
2. e2e 兜底：正则 `surrit.com/{uuid}/playlist.m3u8`；
3. 中继探测：同源 → `localhost` 记忆 relay → `127.0.0.1:8931`。

## 四、复现关键实验（供核对）

```bash
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
UUID='a5e4d7c9-2206-4f41-901c-1dd66a6ead27'

# Referer 白名单矩阵
curl -sS -o /dev/null -w '%{http_code}\n' -A "$UA" "https://surrit.com/$UUID/playlist.m3u8"              # 403
curl -sS -o /dev/null -w '%{http_code}\n' -A "$UA" -e 'https://missav.live/ja/x' "https://surrit.com/$UUID/playlist.m3u8"  # 200
curl -sS -o /dev/null -w '%{http_code}\n' -A "$UA" -e 'https://evil.example/x' "$SEG"                    # 403

# Origin 回显
curl -sSI -A "$UA" -e 'https://missav.live/ja/' -H 'Origin: https://missav.live' "..." | grep -i access-control-allow-origin
# → access-control-allow-origin: https://missav.live （仅官方域）
```

## 五、局限

- surrit 的 WAF 是黑盒： **若未来规则收紧为「浏览器 JA3/JA4 才放行」**，中继可切换 curl-impersonate。
- 番号与 surrit UUID 在 missav 后端侧无直接对应关系， **解码失败（如番号不存在、无对应页）自然失败**。
- 仅为个人离线观看场景设计；请勿批量抓取（centos 反 429 的礼貌行为）。
