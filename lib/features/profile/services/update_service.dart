import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:jade/core/utils/github_proxy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

/// GitHub release 资产（APK）。
class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.size,
    required this.downloadUrl,
    this.digest = '',
  });

  factory GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return GitHubReleaseAsset(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      downloadUrl: json['browser_download_url'] as String? ?? '',
      digest: json['digest'] as String? ?? '',
    );
  }

  final String name;
  final int size;
  final String downloadUrl;

  /// GitHub 为资产计算的 SHA-256，格式 `sha256:<hex>`；旧版本可能缺失（空串）。
  final String digest;
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

/// 安装包哈希校验结果状态。
enum UpdateHashStatus {
  /// 实际 SHA-256 与期望哈希一致。
  verified,

  /// 实际 SHA-256 与期望哈希不一致。
  mismatch,

  /// 无法确定期望哈希或无法计算本地哈希（fail-closed，不安装）。
  unavailable,
}

/// 安装包哈希校验结果。
class UpdateHashVerifyResult {
  const UpdateHashVerifyResult({
    required this.status,
    this.expectedHash,
    this.actualHash,
  });

  final UpdateHashStatus status;

  /// 发行版期望哈希（小写十六进制）；无法确定时为 null。
  final String? expectedHash;

  /// 本地 APK 实际 SHA-256（小写十六进制）；无法计算时为 null。
  final String? actualHash;
}

final RegExp _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

/// 解析安装包哈希，支持两种来源：
///
/// - GitHub `digest` 字段：`sha256:<hex>`；
/// - CI 上传的 `.sha256` 文件（sha256sum 输出）：`<hex>  <文件路径>`。
///
/// 忽略 `sha256:` 前缀与十六进制大小写；格式非法（非 64 位十六进制）返回 null，
/// 视为无法校验。
String? parseApkDigest(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('sha256:')) {
    final value = trimmed
        .substring('sha256:'.length)
        .split(RegExp(r'\s'))
        .first
        .toLowerCase();
    return _hex64.hasMatch(value) ? value : null;
  }
  final token = trimmed.split(RegExp(r'\s+')).first.toLowerCase();
  return _hex64.hasMatch(token) ? token : null;
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
  }) : _client = client ?? http.Client(),
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

  /// 解析期望 SHA-256：优先资产 `digest` 字段；缺失或非法时回退下载
  /// 同名 `.sha256` 文件（CI sha256sum 输出）解析。两者都不可用时返回
  /// null，视为无法校验。
  Future<String?> resolveExpectedSha256(GitHubReleaseAsset asset) async {
    final fromDigest = parseApkDigest(asset.digest);
    if (fromDigest != null) return fromDigest;
    try {
      final url = Uri.parse(
        buildGitHubUrl(proxy, '${asset.downloadUrl}.sha256'),
      );
      final response = await _client.get(url);
      if (response.statusCode != 200) return null;
      return parseApkDigest(response.body);
    } catch (_) {
      return null;
    }
  }

  /// 流式计算本地文件 SHA-256，返回小写十六进制。
  static Future<String> computeFileSha256(String filePath) async {
    final digest = await sha256.bind(File(filePath).openRead()).first;
    return digest.toString();
  }

  /// 校验已下载的 APK：实际 SHA-256 与期望哈希一致返回 verified；
  /// 不一致返回 mismatch；期望哈希不可用或本地文件无法读取返回
  /// unavailable。
  Future<UpdateHashVerifyResult> verifyApk(
    String filePath,
    GitHubReleaseAsset asset,
  ) async {
    final expected = await resolveExpectedSha256(asset);
    if (expected == null) {
      return const UpdateHashVerifyResult(status: UpdateHashStatus.unavailable);
    }
    final String actual;
    try {
      actual = await computeFileSha256(filePath);
    } catch (_) {
      return UpdateHashVerifyResult(
        status: UpdateHashStatus.unavailable,
        expectedHash: expected,
      );
    }
    return UpdateHashVerifyResult(
      status: actual == expected
          ? UpdateHashStatus.verified
          : UpdateHashStatus.mismatch,
      expectedHash: expected,
      actualHash: actual,
    );
  }

  /// 删除已下载的 APK（校验不一致时调用）；文件不存在或删除失败不抛出，
  /// 重新下载时会整体覆盖。
  Future<void> deleteApk(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 无法删除时不阻塞提示流程。
    }
  }
}
