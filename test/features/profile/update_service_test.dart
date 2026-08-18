import 'dart:convert';

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
  });
}
