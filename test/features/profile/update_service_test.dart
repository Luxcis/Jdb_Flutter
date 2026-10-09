import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jade/core/utils/github_proxy.dart';
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

const _releaseJsonWithDigestSource = '''
{
  "tag_name": "v0.10.0",
  "name": "v0.10.0",
  "body": "",
  "assets": [
    {
      "name": "app-arm64-v8a-release.apk",
      "size": 36009801,
      "digest": "sha256:__DIGEST__",
      "browser_download_url":
          "https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-arm64-v8a-release.apk"
    }
  ]
}
''';

void main() {
  const helloSha256 =
      '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824';
  final releaseJsonWithDigest = _releaseJsonWithDigestSource.replaceFirst(
    '__DIGEST__',
    'a' * 64,
  );

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

    test('解析资产 digest 字段，旧格式缺失时为空串', () {
      final release = GitHubRelease.fromJson(
        jsonDecode(_releaseJson) as Map<String, dynamic>,
      );
      expect(release.assets.first.digest, '');

      final withDigest = GitHubRelease.fromJson(
        jsonDecode(releaseJsonWithDigest) as Map<String, dynamic>,
      );
      expect(withDigest.assets.first.digest, 'sha256:${'a' * 64}');
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
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
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
          return http.Response.bytes(
            List<int>.filled(64, 1),
            200,
            headers: {'content-length': '64'},
          );
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

  group('parseApkDigest', () {
    test('解析 digest 字段 sha256:<hex> 并转小写', () {
      final upper = 'sha256:${'AB' * 32}';
      expect(parseApkDigest(upper), 'ab' * 32);
    });

    test('解析 sha256sum 输出首列（双空格 + 文件名）', () {
      expect(
        parseApkDigest('$helloSha256  app-arm64-v8a-release.apk'),
        helloSha256,
      );
    });

    test('纯哈希串可直接解析', () {
      expect(parseApkDigest(helloSha256), helloSha256);
    });

    test('无法识别的算法与格式返回 null', () {
      expect(parseApkDigest('md5:$helloSha256'), isNull);
      expect(parseApkDigest('sha256:${'a' * 63}'), isNull);
      expect(parseApkDigest(''), isNull);
      expect(parseApkDigest('not-a-hash'), isNull);
    });
  });

  group('UpdateInstaller.resolveExpectedSha256', () {
    GitHubReleaseAsset assetWithDigest(String digest) => GitHubReleaseAsset(
      name: 'app-arm64-v8a-release.apk',
      size: 100,
      downloadUrl:
          'https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-arm64-v8a-release.apk',
      digest: digest,
    );

    test('digest 可用时直接返回且不发网络请求', () async {
      var requested = 0;
      final installer = UpdateInstaller(
        client: MockClient((request) async {
          requested++;
          return http.Response('should-not-be-called', 200);
        }),
      );

      final result = await installer.resolveExpectedSha256(
        assetWithDigest('sha256:$helloSha256'),
      );

      expect(result, helloSha256);
      expect(requested, 0);
    });

    test('digest 缺失时下载同名 .sha256 文件并按代理拼接 URL', () async {
      final installer = UpdateInstaller(
        proxy: 'https://hub.luxcis.top/',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://hub.luxcis.top/https://github.com/Luxcis/Jdb_Flutter/releases/download/v0.10.0/app-arm64-v8a-release.apk.sha256',
          );
          return http.Response(
            '$helloSha256  app-arm64-v8a-release.apk\n',
            200,
          );
        }),
        downloadDir: Directory.systemTemp.createTempSync('update_test'),
      );

      final result = await installer.resolveExpectedSha256(assetWithDigest(''));

      expect(result, helloSha256);
    });

    test('digest 缺失且 .sha256 请求失败时返回 null', () async {
      final installer = UpdateInstaller(
        client: MockClient((request) async {
          return http.Response('error', 500);
        }),
        downloadDir: Directory.systemTemp.createTempSync('update_test'),
      );

      final result = await installer.resolveExpectedSha256(assetWithDigest(''));

      expect(result, isNull);
    });

    test('digest 格式非法时回退下载 .sha256 文件', () async {
      final installer = UpdateInstaller(
        client: MockClient((request) async {
          return http.Response('$helloSha256  app-arm64-v8a-release.apk', 200);
        }),
        downloadDir: Directory.systemTemp.createTempSync('update_test'),
      );

      final result = await installer.resolveExpectedSha256(
        assetWithDigest('md5:${'c' * 32}'),
      );

      expect(result, helloSha256);
    });
  });

  group('UpdateInstaller.computeFileSha256', () {
    test('流式计算结果与参考值一致', () async {
      final dir = Directory.systemTemp.createTempSync('update_test');
      final file = File('${dir.path}/hello.bin')..writeAsStringSync('hello');

      final digest = await UpdateInstaller.computeFileSha256(file.path);

      expect(digest, helloSha256);
      expect(digest, digest.toLowerCase());
    });
  });

  group('UpdateInstaller.verifyApk', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('update_test');
    });

    GitHubReleaseAsset buildAsset(String digest) => GitHubReleaseAsset(
      name: 'app-arm64-v8a-release.apk',
      size: 100,
      downloadUrl: 'https://example.com/app.apk',
      digest: digest,
    );

    test('实际哈希与 digest 一致返回 verified（大小写不敏感）', () async {
      final file = File('${dir.path}/app.apk')..writeAsStringSync('hello');
      final installer = UpdateInstaller();
      final asset = buildAsset('sha256:${helloSha256.toUpperCase()}');

      final verification = await installer.verifyApk(file.path, asset);

      expect(verification.status, UpdateHashStatus.verified);
      expect(verification.expectedHash, helloSha256);
      expect(verification.actualHash, helloSha256);
    });

    test('实际哈希与期望不一致返回 mismatch', () async {
      final file = File('${dir.path}/app.apk')..writeAsStringSync('tampered');
      final installer = UpdateInstaller();
      final asset = buildAsset('sha256:$helloSha256');

      final verification = await installer.verifyApk(file.path, asset);

      expect(verification.status, UpdateHashStatus.mismatch);
      expect(verification.actualHash, isNot(verification.expectedHash));
    });

    test('digest 缺失且 .sha256 文件可用时按文件内容校验', () async {
      final file = File('${dir.path}/app.apk')..writeAsStringSync('hello');
      final installer = UpdateInstaller(
        client: MockClient((request) async {
          return http.Response('$helloSha256  app.apk', 200);
        }),
        downloadDir: dir,
      );
      final asset = buildAsset('');

      final verification = await installer.verifyApk(file.path, asset);

      expect(verification.status, UpdateHashStatus.verified);
    });

    test('期望哈希不可用返回 unavailable 且不读取本地文件', () async {
      final installer = UpdateInstaller(
        client: MockClient((request) async {
          return http.Response('error', 404);
        }),
        downloadDir: dir,
      );
      final asset = buildAsset('');

      final verification = await installer.verifyApk(
        '${dir.path}/missing.apk',
        asset,
      );

      expect(verification.status, UpdateHashStatus.unavailable);
      expect(verification.expectedHash, isNull);
    });

    test('本地文件缺失返回 unavailable', () async {
      final installer = UpdateInstaller();
      final asset = buildAsset('sha256:$helloSha256');

      final verification = await installer.verifyApk(
        '${dir.path}/missing.apk',
        asset,
      );

      expect(verification.status, UpdateHashStatus.unavailable);
      expect(verification.expectedHash, helloSha256);
    });
  });

  group('UpdateInstaller.deleteApk', () {
    test('删除已存在的文件', () async {
      final dir = Directory.systemTemp.createTempSync('update_test');
      final file = File('${dir.path}/app.apk')..writeAsStringSync('x');
      final installer = UpdateInstaller();

      await installer.deleteApk(file.path);

      expect(file.existsSync(), isFalse);
    });

    test('文件不存在时不抛出', () async {
      final installer = UpdateInstaller();

      await installer.deleteApk(
        '${Directory.systemTemp.createTempSync('update_test').path}/missing.apk',
      );
    });
  });
}
