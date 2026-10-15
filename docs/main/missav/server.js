#!/usr/bin/env node
/**
 * MissAV 本地中继服务器（零 npm 依赖，Node 18+，依赖系统 curl）
 *
 * 为什么必须走 curl 子进程做上游：
 *   实测 surrit.com 的 Cloudflare WAF 按「客户端 TLS/HTTP 指纹 + Referer 白名单」放行：
 *   带 missav Referer 时，curl（h1/h2、直连或代理）恒 200；而相同 Header 下
 *   undici fetch / undici h2 / node https 一律 403。故上游请求用
 *   spawn('curl')，本机 Node 仅负责路由、透传 Range 与流式回传。
 *
 * 路由：
 *   GET  /                     → 静态托管同目录 player.html
 *   GET  /page/{码点}          → 代抓 missav 页面 HTML（免 CORS / 免 UA 探测质询）
 *   GET  /hls/{UUID}/...       → 反代 surrit.com（注入 Referer，流式转发，含 Range）
 *
 * 参考 README.md 的反爬结论。
 */
'use strict'

const http = require('http')
const https = require('https')
const fs = require('fs')
const path = require('path')
const { spawn } = require('child_process')

const PORT = Number(process.env.PORT || 8931)
const PAGE_HOST = 'https://missav.live'
const HLS_HOST = 'https://surrit.com'
const REFERER = process.env.MISSAV_REFERER || 'https://missav.live/ja/'
const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

function setCORS(res) {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Headers', 'range,content-type')
  res.setHeader('Access-Control-Expose-Headers',
    'content-length,content-range,content-type,accept-ranges')
}

const FORWARD_HLS = new Set([
  'content-type', 'content-length', 'content-range', 'accept-ranges',
  'last-modified', 'etag', 'expires', 'cache-control',
])
const FORWARD_PAGE = new Set(['content-type'])

/**
 * 用系统 curl 做上游请求并流式回传。
 * curl -sS 将响应头与响应体写到同一个 stdout：可能包含多段 HTTP 头块
 * （例如 -x 代理的 "Connection established" 伪块、-L 的重定向跳头）。
 * 因此按顺序扫描头块：优先取「第一个带 content-type 的正规块」，
 * 否则取最后一个块；伪块（无 content-type）一律跳过。
 */
function curlRelay(url, headers, res, forwardSet, { useProxy } = { useProxy: true }) {
  const args = [
    '-sS', '--max-time', '120', '-D', '-',
  ]
  if (!useProxy) args.push('--noproxy', '*')
  args.push(...headers, url)
  const child = spawn('curl', args, { stdio: ['ignore', 'pipe', 'pipe'] })

  let stderr = ''
  child.stderr.on('data', (d) => (stderr += d))

  let buf = Buffer.alloc(0)
  let headParsed = false

  const parseHeadBlock = (headText) => {
    const lines = headText.split('\r\n')
    let statusLine = ''
    const collected = {}
    for (const line of lines) {
      if (/^HTTP\//i.test(line)) statusLine = line
      else {
        const idx = line.indexOf(':')
        if (idx > 0) {
          const k = line.slice(0, idx).trim().toLowerCase()
          const v = line.slice(idx + 1).trim()
          collected[k] = v
        }
      }
    }
    // statusLine / collected 全转为块元数据
    return { statusLine, collected }
  }

  child.stdout.on('data', (chunk) => {
    if (headParsed) {
      // 头已确定：其余全部视作 body 直传
      res.write(chunk)
      return
    }
    buf = Buffer.concat([buf, chunk])

    // 顺序扫描头块：pos 起，找最近的 CRLFCRLF 边界，解析成块；继续找下一段
    let pos = 0
    let chosen = null // { status, out }
    let statusFromLast = null
    for (;;) {
      const mark = buf.indexOf(Buffer.from('\r\n\r\n'), pos)
      if (mark < 0) break // 剩余为不完整块，等更多数据
      const headText = buf.slice(pos, mark).toString('latin1')
      const block = parseHeadBlock(headText)
      const status = Number((block.statusLine.match(/HTTP\/[\d.]+ (\d+)/) || [])[1]) || 0
      statusFromLast = { status, collected: block.collected }
      if (/^HTTP\//i.test(block.statusLine) && block.collected['content-type']) {
        const out = {}
        for (const k of forwardSet) if (block.collected[k] != null) out[k] = block.collected[k]
        chosen = { status, out }
      }
      pos = mark + 4
    }

    if (chosen) {
      headParsed = true
      setCORS(res)
      res.writeHead(chosen.status, chosen.out)
      const rest = buf.slice(pos)
      if (rest.length) res.write(rest)
    } else if (statusFromLast && buf.length > 0) {
      // 不确定是否仍有后续头块，继续等待下一 chunk；超长兜底
      if (buf.length > 65536) {
        headParsed = true
        const out = {}
        for (const k of forwardSet) if (statusFromLast.collected[k] != null) out[k] = statusFromLast.collected[k]
        setCORS(res)
        res.writeHead(statusFromLast.status || 200, out)
        const rest = buf.slice(pos)
        if (rest.length) res.write(rest)
      }
    }
  })

  child.stdout.on('end', () => {
    if (!headParsed) {
      console.error('[relay] curl stream ended before complete header')
      if (!res.headersSent) res.writeHead(502)
    }
    res.end()
  })
  child.stderr.on('end', () => {
    if (stderr && !headParsed) console.error('[relay curl]', stderr.trim().split('\n').slice(-3).join(' | '))
  })
  child.on('error', (err) => {
    console.error('[relay] spawn curl fail:', err.message)
    if (!res.headersSent) { res.writeHead(502); res.end('curl spawn fail') }
    else res.destroy()
  })

  // 客户端断开（用户暂停/关闭播放器）时终止上游，避免残留 curl 进程
  res.on('close', () => {
    if (!child.destroyed) child.kill('SIGKILL')
  })
  return child
}

function hlsHeaderArgs(extra) {
  const h = [
    '-H', `User-Agent: ${UA}`,
    '-H', `Referer: ${REFERER}`,
    '-H', 'Accept: */*',
    '-H', 'Accept-Language: zh-CN,zh-Hans;q=0.9,en;q=0.8',
  ]
  for (const [k, v] of Object.entries(extra || {})) h.push('-H', `${k}: ${v}`)
  return h
}

const server = http.createServer(async (req, res) => {
  try {
    const u = new URL(req.url, `http://127.0.0.1:${PORT}`)
    setCORS(res)

    if (req.method === 'OPTIONS') return res.writeHead(204).end()

    if (u.pathname === '/' || u.pathname === '/index.html') {
      const file = path.join(__dirname, 'player.html')
      if (fs.existsSync(file)) {
        res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' })
        return fs.createReadStream(file).on('error', (e) => res.destroy(e)).pipe(res)
      }
      res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' })
      return res.end('player.html 缺失：请放在 server.js 同目录')
    }

    // ---- HLS 反代 ----
    let m = u.pathname.match(/^\/hls\/(.+)$/)
    if (m) {
      const rest = decodeURIComponent(m[1]).replace(/^https?:\/\/surrit\.com\//, '')
      if (!/^[\w./-]+$/.test(rest)) { res.writeHead(400).end('bad hls path'); return }
      const extra = {}
      if (req.headers.range) extra.Range = req.headers.range
      // surrit 直连可达；绕过代理 CONNECT 伪头部，直接拿上游真实头
      return void curlRelay(`${HLS_HOST}/${rest}`, hlsHeaderArgs(extra), res, FORWARD_HLS, { useProxy: false })
    }

    // ---- 页面抓取 ----
    m = u.pathname.match(/^\/page\/([^/]+)$/)
    if (m) {
      const code = decodeURIComponent(m[1])
      if (!/^[\w-]{3,64}$/.test(code)) { res.writeHead(400).end('bad code'); return }
      return void curlRelay(
        `${PAGE_HOST}/${code}`,
        [
          '-H', `User-Agent: ${UA}`,
          '-H', 'Accept: text/html,*/*',
          '-H', 'Accept-Language: zh-CN,zh-Hans;q=0.9,en;q=0.8',
          '-L', '--compressed',
        ],
        res,
        FORWARD_PAGE)
    }

    res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' }).end('not found')
  } catch (err) {
    console.error('[relay] error:', err.message)
    if (!res.headersSent) {
      res.writeHead(502, { 'content-type': 'text/plain; charset=utf-8' })
      res.end('relay error: ' + err.message)
    } else res.destroy()
  }
})

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[relay] MissAV 本地中继已启动 → http://127.0.0.1:${PORT} （Referer: ${REFERER}）`)
})
