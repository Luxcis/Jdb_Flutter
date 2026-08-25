import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

/// 代理前缀非空时拼接到完整 URL 前，否则原样返回。
String buildGitHubUrl(String proxy, String fullUrl) =>
    proxy.isEmpty ? fullUrl : '$proxy$fullUrl';

/// 规范化代理前缀：空串保留；非空且不以 / 结尾时自动补齐 /。
String normalizeGithubProxy(String proxy) =>
    proxy.isEmpty || proxy.endsWith('/') ? proxy : '$proxy/';

/// GitHub release 资产（APK）。
class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.size,
    required this.downloadUrl,
  });

  factory GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return GitHubReleaseAsset(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      downloadUrl: json['browser_download_url'] as String? ?? '',
    );
  }

  final String name;
  final int size;
  final String downloadUrl;
}

/// GitHub latest release 解析结果。
class GitHubRelease {
  const GitHubRelease({
    required this.tagName,
    required this.body,
    required this.assets,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    return GitHubRelease(
      tagName: json['tag_name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      assets: [
        for (final asset in json['assets'] as List<dynamic>? ?? const [])
          if (asset is Map<String, dynamic>) GitHubReleaseAsset.fromJson(asset),
      ],
    );
  }

  final String tagName;
  final String body;
  final List<GitHubReleaseAsset> assets;
}

/// 版本检查结果。
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.release,
    required this.hasUpdate,
    required this.latestVersion,
  });

  final GitHubRelease release;
  final bool hasUpdate;
  final String latestVersion;
}

/// 查询 GitHub latest release 并与本地版本比较。
class UpdateChecker {
  UpdateChecker({
    required this.currentVersion,
    this.proxy = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String currentVersion;
  final String proxy;
  final http.Client _client;

  static const _apiUrl =
      'https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest';

  Uri _releaseUrl() => Uri.parse(buildGitHubUrl(proxy, _apiUrl));

  /// 请求 latest release 并判断是否有新版本。
  Future<UpdateCheckResult> check() async {
    final response = await _client.get(_releaseUrl());
    if (response.statusCode != 200) {
      throw Exception('GitHub release 请求失败：HTTP ${response.statusCode}');
    }
    final release = GitHubRelease.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    final latestVersion = release.tagName.replaceFirst(RegExp(r'^v'), '');
    final hasUpdate = _isNewer(latestVersion, currentVersion);
    return UpdateCheckResult(
      release: release,
      hasUpdate: hasUpdate,
      latestVersion: latestVersion,
    );
  }

  /// 语义化版本比较：latest > current 返回 true；解析失败返回 false。
  bool _isNewer(String latest, String current) {
    try {
      return Version.parse(latest) > Version.parse(current);
    } on FormatException {
      return false;
    }
  }
}

/// 下载 APK 并调起系统安装器。
class UpdateInstaller {
  UpdateInstaller({
    this.proxy = '',
    http.Client? client,
    Directory? downloadDir,
  })  : _client = client ?? http.Client(),
        _downloadDir = downloadDir;

  final String proxy;
  final http.Client _client;
  final Directory? _downloadDir;

  /// 按 ABI 优先级从 release 资产中挑选 APK。
  GitHubReleaseAsset pickAsset(
    GitHubRelease release,
    List<String> supportedAbis,
  ) {
    for (final abi in supportedAbis) {
      for (final asset in release.assets) {
        if (asset.name.contains(abi)) return asset;
      }
    }
    return release.assets.first;
  }

  /// 流式下载 APK 到应用文档目录，返回本地文件路径。
  Future<String> download(
    GitHubReleaseAsset asset, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = _downloadDir ?? await getApplicationDocumentsDirectory();
    final targetDir = Directory('${dir.path}/update');
    await targetDir.create(recursive: true);

    final request = http.Request(
      'GET',
      Uri.parse(buildGitHubUrl(proxy, asset.downloadUrl)),
    );
    final streamed = await _client.send(request);
    if (streamed.statusCode != 200) {
      throw Exception('APK 下载失败：HTTP ${streamed.statusCode}');
    }
    final total = streamed.contentLength ?? asset.size;
    final file = File('${targetDir.path}/app-jade.apk');
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in streamed.stream) {
      received += chunk.length;
      sink.add(chunk);
      onProgress?.call(received, total);
    }
    await sink.close();
    return file.path;
  }
}
