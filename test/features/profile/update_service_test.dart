import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jade/features/profile/services/update_service.dart';

/// 构造一个 fake http.Client，返回固定 release JSON。
http.Client _fakeClient(String body, {int status = 200}) {
  return MockClient((request) async {
    expect(
      request.url.toString(),
      'https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest',
    );
    if (status != 200) {
      return http.Response('error', status);
    }
    return http.Response(
      body,
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

const _releaseJson = '''
{
  "tag_name": "v0.10.0",
  "name": "v0.10.0",
  "body": "## What's Changed\\n* feat: new stuff",
  "assets": [
    {
      "name": "app-arm64-v8a-release.apk",
      "size": 36009801,
      "browser_download_url":
          "https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-arm64-v8a-release.apk"
    },
    {
      "name": "app-armeabi-v7a-release.apk",
      "size": 33092905,
      "browser_download_url":
          "https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-armeabi-v7a-release.apk"
    },
    {
      "name": "app-x86_64-release.apk",
      "size": 40898231,
      "browser_download_url":
          "https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-x86_64-release.apk"
    }
  ]
}
''';

void main() {
  group('GitHubRelease JSON 解析', () {
    test('解析 tagName/body/assets', () {
      final release = GitHubRelease.fromJson(
        jsonDecode(_releaseJson) as Map<String, dynamic>,
      );

      expect(release.tagName, 'v0.10.0');
      expect(release.body, contains('feat: new stuff'));
      expect(release.assets, hasLength(3));
      expect(release.assets.first.name, 'app-arm64-v8a-release.apk');
      expect(release.assets.first.size, 36009801);
      expect(
        release.assets.first.downloadUrl,
        contains('app-arm64-v8a-release.apk'),
      );
    });
  });

  group('buildGitHubUrl', () {
    test('空代理原样返回', () {
      expect(
        buildGitHubUrl('', 'https://api.github.com/a'),
        'https://api.github.com/a',
      );
    });

    test('非空代理前缀拼接', () {
      expect(
        buildGitHubUrl('https://hub.luxcis.top/', 'https://api.github.com/a'),
        'https://hub.luxcis.top/https://api.github.com/a',
      );
    });
  });

  group('normalizeGithubProxy', () {
    test('空串保持不变', () {
      expect(normalizeGithubProxy(''), '');
    });
    test('已以 / 结尾保持不变', () {
      expect(
        normalizeGithubProxy('https://hub.luxcis.top/'),
        'https://hub.luxcis.top/',
      );
    });
    test('未以 / 结尾自动补齐', () {
      expect(
        normalizeGithubProxy('https://hub.luxcis.top'),
        'https://hub.luxcis.top/',
      );
    });
  });

  group('UpdateChecker', () {
    test('远端版本更高时 hasUpdate=true', () async {
      final checker = UpdateChecker(
        client: _fakeClient(_releaseJson),
        currentVersion: '0.9.2',
      );

      final result = await checker.check();

      expect(result.hasUpdate, isTrue);
      expect(result.latestVersion, '0.10.0');
      expect(result.release.tagName, 'v0.10.0');
    });

    test('版本相同或更低时 hasUpdate=false', () async {
      final sameJson = _releaseJson.replaceFirst('v0.10.0', 'v0.9.2');
      final checker = UpdateChecker(
        client: _fakeClient(sameJson),
        currentVersion: '0.9.2',
      );

      final result = await checker.check();

      expect(result.hasUpdate, isFalse);
      expect(result.latestVersion, '0.9.2');
    });

    test('HTTP 非 200 抛出异常', () async {
      final checker = UpdateChecker(
        client: _fakeClient('', status: 500),
        currentVersion: '0.9.2',
      );

      expect(checker.check(), throwsException);
    });

    test('tag 无法解析时不视为更新', () async {
      final badJson = _releaseJson.replaceFirst('v0.10.0', 'not-a-version');
      final checker = UpdateChecker(
        client: _fakeClient(badJson),
        currentVersion: '0.9.2',
      );

      final result = await checker.check();

      expect(result.hasUpdate, isFalse);
    });

    test('配置代理时请求 URL 拼接代理前缀', () async {
      final checker = UpdateChecker(
        currentVersion: '0.9.2',
        proxy: 'https://hub.luxcis.top/',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://hub.luxcis.top/https://api.github.com/repos/Luxcis/Jdb_Flutter/releases/latest',
          );
          return http.Response('{}', 200,
              headers: {'content-type': 'application/json'});
        }),
      );

      final result = await checker.check();

      // 空 release JSON -> tagName '' -> Version.parse 失败 -> hasUpdate=false
      expect(result.hasUpdate, isFalse);
    });
  });

  group('UpdateInstaller.pickAsset', () {
    const abis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];

    GitHubRelease releaseWith(List<String> names) => GitHubRelease(
      tagName: 'v0.10.0',
      body: '',
      assets: [
        for (final name in names)
          GitHubReleaseAsset(
            name: name,
            size: 100,
            downloadUrl: 'https://example.com/$name',
          ),
      ],
    );

    test('按 supportedAbis 顺序匹配资产', () {
      final release = releaseWith([
        'app-armeabi-v7a-release.apk',
        'app-x86_64-release.apk',
        'app-arm64-v8a-release.apk',
      ]);
      final installer = UpdateInstaller();

      final asset = installer.pickAsset(release, abis);

      expect(asset.name, contains('arm64-v8a'));
    });

    test('无匹配时回退第一个资产', () {
      final release = releaseWith(['app-unknown-abi-release.apk']);
      final installer = UpdateInstaller();

      final asset = installer.pickAsset(release, abis);

      expect(asset.name, 'app-unknown-abi-release.apk');
    });
  });

  group('UpdateInstaller.download', () {
    test('下载文件并报告进度', () async {
      final installer = UpdateInstaller(
        client: MockClient((request) async {
          return http.Response.bytes(
            List<int>.filled(1024, 7),
            200,
            headers: {'content-length': '1024'},
          );
        }),
        downloadDir: Directory.systemTemp.createTempSync('update_test'),
      );
      final progress = <int>[];
      final asset = const GitHubReleaseAsset(
        name: 'app-arm64-v8a-release.apk',
        size: 1024,
        downloadUrl: 'https://example.com/app.apk',
      );

      final path = await installer.download(
        asset,
        onProgress: (received, total) => progress.add(received),
      );

      expect(await File(path).length(), 1024);
      expect(progress.last, 1024);
    });

    test('配置代理时下载 URL 拼接代理前缀', () async {
      final installer = UpdateInstaller(
        proxy: 'https://hub.luxcis.top/',
        downloadDir: Directory.systemTemp.createTempSync('update_test'),
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://hub.luxcis.top/https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-arm64-v8a-release.apk',
          );
          return http.Response.bytes(List<int>.filled(64, 1), 200,
              headers: {'content-length': '64'});
        }),
      );
      final asset = const GitHubReleaseAsset(
        name: 'app-arm64-v8a-release.apk',
        size: 64,
        downloadUrl:
            'https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-arm64-v8a-release.apk',
      );

      final path = await installer.download(asset);

      expect(await File(path).length(), 64);
    });
  });
}
