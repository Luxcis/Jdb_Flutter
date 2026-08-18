import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

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
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String currentVersion;
  final http.Client _client;

  static const _apiUrl =
      'https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest';

  /// 请求 latest release 并判断是否有新版本。
  Future<UpdateCheckResult> check() async {
    final response = await _client.get(Uri.parse(_apiUrl));
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
