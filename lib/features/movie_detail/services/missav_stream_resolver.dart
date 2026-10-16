import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:jade/features/movie_detail/services/missav_page_parser.dart';

/// MissAV 页面与 CDN 共用浏览器 UA（与 `docs/main/missav/server.js` 一致）。
const missavUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/// surrit CDN 的 Referer 白名单要求的来源地址。
const missavReferer = 'https://missav.live/ja/';

/// MissAV 页面主机。
const missavPageHost = 'https://missav.live';

/// 解析出的在线播放信息：播放列表地址与播放请求头。
@immutable
class MissavResolvedStream {
  const MissavResolvedStream({
    required this.playlistUrl,
    required this.httpHeaders,
  });

  final Uri playlistUrl;

  /// 播放器直连 CDN 时必须携带的请求头（Referer 白名单）。
  final Map<String, String> httpHeaders;
}

/// 解析失败异常：`message` 为可直接展示的中文原因。
class MissavResolveException implements Exception {
  const MissavResolveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 番号 → 在线播放信息 的解析接口。
abstract interface class MissavStreamResolver {
  Future<MissavResolvedStream> resolve(String number);
}

/// 通过 missav 页面抓取 + packer 解码的默认解析器。
///
/// HTTP 客户端可注入（测试替身）；生产默认在 Android 使用 Cronet
/// （Chromium 网络栈指纹，通过 WAF 指纹筛选），其他平台回退 dart:io 客户端。
class MissavHttpStreamResolver implements MissavStreamResolver {
  MissavHttpStreamResolver({
    http.Client? client,
    String pageHost = missavPageHost,
  }) : _client = client ?? createMissavHttpClient(),
       _pageHost = pageHost;

  static const _requestTimeout = Duration(seconds: 20);

  final http.Client _client;
  final String _pageHost;

  /// 释放底层 HTTP 客户端（Cronet 引擎随之关闭）。
  void close() => _client.close();

  @override
  Future<MissavResolvedStream> resolve(String number) async {
    final code = normalizeMissavCode(number);
    if (code.isEmpty) {
      throw const MissavResolveException('番号为空，无法解析在线播放地址');
    }

    final pageUri = Uri.parse('$_pageHost/ja/$code');
    final http.Response response;
    try {
      response = await _client
          .get(
            pageUri,
            headers: const {
              'User-Agent': missavUserAgent,
              'Accept': 'text/html,*/*',
              'Accept-Language': 'zh-CN,zh-Hans;q=0.9,en;q=0.8',
            },
          )
          .timeout(_requestTimeout);
    } on Object catch (error) {
      throw MissavResolveException('页面请求失败：$error');
    }

    if (response.statusCode != 200) {
      throw MissavResolveException(
        '页面请求失败（HTTP ${response.statusCode}），番号可能不存在',
      );
    }

    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final master = extractSurritMasterUrl(html);
    if (master == null) {
      throw const MissavResolveException('未在页面中找到播放列表，番号可能不存在');
    }

    return MissavResolvedStream(
      playlistUrl: Uri.parse(master),
      httpHeaders: const {
        'Referer': missavReferer,
        'User-Agent': missavUserAgent,
      },
    );
  }
}

/// 创建生产环境 HTTP 客户端：Android 用 Cronet，其他平台回退 dart:io。
///
/// Cronet 以 embedded 变体构建（`--dart-define=cronetHttpNoPlay=true`），
/// 无 Google Play 服务的设备同样可用；参见 `RULES.md` 构建约定。
http.Client createMissavHttpClient() {
  if (!kIsWeb && Platform.isAndroid) {
    final engine = CronetEngine.build(
      cacheMode: CacheMode.memory,
      userAgent: missavUserAgent,
    );
    return CronetClient.fromCronetEngine(engine, closeEngine: true);
  }
  return IOClient(HttpClient()..userAgent = missavUserAgent);
}
