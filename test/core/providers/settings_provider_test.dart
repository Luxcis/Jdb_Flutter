import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/storage/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('影片图片模糊默认开启', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = await SettingsProvider.create(prefs);

    expect(provider.blurMovieImages, isTrue);
  });

  test('恢复已保存的影片图片模糊设置', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.blurMovieImages: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = await SettingsProvider.create(prefs);

    expect(provider.blurMovieImages, isFalse);
  });

  test('切换影片图片模糊后持久化并通知监听者', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = await SettingsProvider.create(prefs);
    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.setBlurMovieImages(false);

    expect(provider.blurMovieImages, isFalse);
    expect(prefs.getBool(StorageKeys.blurMovieImages), isFalse);
    expect(notifications, 1);
  });

  test('GitHub 代理默认关闭（空串）', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = await SettingsProvider.create(prefs);

    expect(provider.githubProxy, '');
  });

  test('恢复已保存的 GitHub 代理', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.githubProxy: 'https://hub.luxcis.top/',
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = await SettingsProvider.create(prefs);

    expect(provider.githubProxy, 'https://hub.luxcis.top/');
  });

  test('切换 GitHub 代理后持久化并通知监听者', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = await SettingsProvider.create(prefs);
    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.setGithubProxy('https://gh-proxy.com/');

    expect(provider.githubProxy, 'https://gh-proxy.com/');
    expect(prefs.getString(StorageKeys.githubProxy), 'https://gh-proxy.com/');
    expect(notifications, 1);
  });
}
