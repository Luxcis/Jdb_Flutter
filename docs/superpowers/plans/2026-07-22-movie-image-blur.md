# 影片图片模糊 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为影片 thumb、cover 和剧照增加默认开启、可持久化并可在设置页切换的统一模糊功能。

**Architecture:** `SettingsProvider` 作为模糊开关的唯一状态源并通过 SharedPreferences 持久化。`CachedImage` 只负责对成功加载的网络图片应用可选高斯模糊，`MovieCoverImage` 与新增的 `MovieScreenshotImage` 负责读取全局设置并声明影片图片属于敏感内容。

**Tech Stack:** Flutter、Dart、Provider、SharedPreferences、cached_network_image、flutter_test

## Global Constraints

- 模糊开关首次安装时默认开启。
- 模糊范围仅包含影片 `thumb`、影片 `cover` 和影片剧照。
- 演员头像和网络失败后的本地占位图必须保持清晰。
- 固定使用 `sigmaX = 12`、`sigmaY = 12`，不增加强度调节和单图解锁。
- 不增加依赖，不改变图片 URL 选择、缓存、解密、裁剪比例或占位图映射。
- 设置文案使用项目约定的中文硬编码。

---

### Task 1: 持久化影片图片模糊设置

**Files:**
- Modify: `lib/core/storage/storage_keys.dart`
- Modify: `lib/core/providers/settings_provider.dart`
- Create: `test/core/providers/settings_provider_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences.getBool(String)`、`SharedPreferences.setBool(String, bool)`。
- Produces: `StorageKeys.blurMovieImages`、`SettingsProvider.blurMovieImages`、`Future<void> SettingsProvider.setBlurMovieImages(bool value)`。

- [ ] **Step 1: 写默认值和持久化失败测试**

```dart
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
}
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/core/providers/settings_provider_test.dart`

Expected: FAIL，提示 `blurMovieImages`、`setBlurMovieImages` 或 `StorageKeys.blurMovieImages` 未定义。

- [ ] **Step 3: 增加存储键和最小 provider 实现**

```dart
// lib/core/storage/storage_keys.dart
static const String blurMovieImages = 'key_blur_movie_images';

// lib/core/providers/settings_provider.dart
bool _blurMovieImages = true;

bool get blurMovieImages => _blurMovieImages;

static Future<SettingsProvider> create(SharedPreferences prefs) async {
  final p = SettingsProvider._(prefs);
  p._blurMovieImages = prefs.getBool(StorageKeys.blurMovieImages) ?? true;
  final raw = prefs.getString(StorageKeys.defaultFilterTags);
  if (raw != null) {
    p._defaultFilterTags = List<String>.from(jsonDecode(raw) as List);
  }
  return p;
}

Future<void> setBlurMovieImages(bool value) async {
  _blurMovieImages = value;
  await _prefs.setBool(StorageKeys.blurMovieImages, value);
  notifyListeners();
}
```

- [ ] **Step 4: 运行测试并确认 GREEN**

Run: `flutter test test/core/providers/settings_provider_test.dart`

Expected: PASS，3 项测试全部通过。

- [ ] **Step 5: 提交设置状态实现**

```bash
git add lib/core/storage/storage_keys.dart lib/core/providers/settings_provider.dart test/core/providers/settings_provider_test.dart
git commit -m "feat: persist movie image blur setting"
```

### Task 2: 只模糊成功加载的网络图片

**Files:**
- Modify: `lib/core/widgets/cached_image.dart`
- Modify: `test/core/widgets/cached_image_test.dart`

**Interfaces:**
- Consumes: `CachedNetworkImage.imageBuilder` 和 Flutter `ImageFiltered`。
- Produces: `CachedImage(..., bool blur = false)`；模糊开启时成功图片使用 `ImageFilter.blur(sigmaX: 12, sigmaY: 12)`。

- [ ] **Step 1: 写成功图片与错误占位边界测试**

```dart
testWidgets('blur 开启时仅成功加载的网络图片使用模糊层', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: CachedImage(
        'covers/test.jpg',
        blur: true,
        fallbackAsset: 'assets/images/noimage_600x404.jpg',
      ),
    ),
  );

  final networkImage = tester.widget<CachedNetworkImage>(
    find.byType(CachedNetworkImage),
  );
  final context = tester.element(find.byType(CachedImage));
  final success = networkImage.imageBuilder!(
    context,
    const AssetImage('assets/images/noimage_600x404.jpg'),
  );
  final error = networkImage.errorWidget!(context, 'url', StateError('fail'));

  final clip = success as ClipRect;
  expect(clip.child, isA<ImageFiltered>());
  expect(error, isA<Image>());
  expect(error, isNot(isA<ImageFiltered>()));
});

testWidgets('blur 关闭时不配置成功图片模糊构建器', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: CachedImage('covers/test.jpg')),
  );

  final networkImage = tester.widget<CachedNetworkImage>(
    find.byType(CachedNetworkImage),
  );
  expect(networkImage.imageBuilder, isNull);
});
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/core/widgets/cached_image_test.dart`

Expected: FAIL，提示 `blur` 参数未定义。

- [ ] **Step 3: 实现成功图片专用模糊构建器**

```dart
import 'dart:ui';

class CachedImage extends StatelessWidget {
  const CachedImage(
    this.url, {
    super.key,
    this.aspect,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackAsset,
    this.semanticLabel,
    this.blur = false,
  });

  final String url;
  final double? aspect;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? fallbackAsset;
  final String? semanticLabel;
  final bool blur;

  String get _fullUrl {
    if (url.startsWith('http')) return url;
    final endpoint =
        ApiClient.instanceOrNull?.domainManager.imageEndpoint ??
        AppConstants.fallbackImageCdn;
    return '$endpoint$url';
  }

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: _fullUrl,
      cacheManager: JdbImageCacheManager.instance,
      fit: fit,
      width: width,
      height: height,
      imageBuilder: blur
          ? (_, imageProvider) => ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Image(
                  image: imageProvider,
                  width: width,
                  height: height,
                  fit: fit,
                ),
              ),
            )
          : null,
      placeholder: (_, _) => const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, _, _) => fallbackAsset == null
          ? const Center(child: Icon(Icons.broken_image))
          : Image.asset(fallbackAsset!, width: width, height: height, fit: fit),
    );
    final label = semanticLabel;
    if (label == null) return image;
    return Semantics(
      image: true,
      label: label,
      excludeSemantics: true,
      child: image,
    );
  }
}
```

- [ ] **Step 4: 运行测试并确认 GREEN**

Run: `flutter test test/core/widgets/cached_image_test.dart`

Expected: PASS，原有 URL、尺寸、错误占位和新增模糊测试全部通过。

- [ ] **Step 5: 提交基础图片模糊能力**

```bash
git add lib/core/widgets/cached_image.dart test/core/widgets/cached_image_test.dart
git commit -m "feat: blur loaded cached images"
```

### Task 3: 将全局开关接入影片封面和剧照组件

**Files:**
- Modify: `lib/core/widgets/movie_cover_image.dart`
- Create: `lib/core/widgets/movie_screenshot_image.dart`
- Modify: `test/core/widgets/movie_cover_image_test.dart`
- Create: `test/core/widgets/movie_screenshot_image_test.dart`

**Interfaces:**
- Consumes: 可选的 `SettingsProvider.blurMovieImages` 和 `CachedImage.blur`；缺少 provider 时按默认开启处理。
- Produces: `MovieScreenshotImage(String url, {Key? key, double? width, double? height, BoxFit fit = BoxFit.cover})`。

- [ ] **Step 1: 更新封面测试并新增剧照 RED 测试**

为两个测试文件使用相同的 provider harness：

```dart
Future<SettingsProvider> createSettings({bool blur = true}) async {
  SharedPreferences.setMockInitialValues({
    StorageKeys.blurMovieImages: blur,
  });
  final prefs = await SharedPreferences.getInstance();
  return SettingsProvider.create(prefs);
}

Future<void> pumpWithSettings(
  WidgetTester tester,
  SettingsProvider settings,
  Widget child,
) {
  return tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(home: child),
    ),
  );
}
```

在 `movie_cover_image_test.dart` 保留 thumbnail/cover 占位断言，并增加：

```dart
testWidgets('影片封面响应全局模糊开关', (tester) async {
  final settings = await createSettings();
  await pumpWithSettings(
    tester,
    settings,
    const MovieCoverImage(
      'covers/test.jpg',
      variant: MovieImageVariant.thumbnail,
    ),
  );
  expect(tester.widget<CachedImage>(find.byType(CachedImage)).blur, isTrue);

  await settings.setBlurMovieImages(false);
  await tester.pump();
  expect(tester.widget<CachedImage>(find.byType(CachedImage)).blur, isFalse);
});
```

新增 `movie_screenshot_image_test.dart`：

```dart
testWidgets('影片剧照响应全局模糊开关', (tester) async {
  final settings = await createSettings(blur: false);
  await pumpWithSettings(
    tester,
    settings,
    const MovieScreenshotImage('screenshots/test.jpg'),
  );

  expect(tester.widget<CachedImage>(find.byType(CachedImage)).blur, isFalse);

  await settings.setBlurMovieImages(true);
  await tester.pump();
  expect(tester.widget<CachedImage>(find.byType(CachedImage)).blur, isTrue);
});
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/core/widgets/movie_cover_image_test.dart test/core/widgets/movie_screenshot_image_test.dart`

Expected: FAIL，封面尚未传递 `blur`，且 `MovieScreenshotImage` 尚不存在。

- [ ] **Step 3: 接入 provider 并创建剧照组件**

```dart
// lib/core/widgets/movie_cover_image.dart
import 'package:jade/core/providers/settings_provider.dart';
import 'package:provider/provider.dart';

@override
Widget build(BuildContext context) {
  final blur = context.watch<SettingsProvider?>()?.blurMovieImages ?? true;
  return CachedImage(
    url,
    width: width,
    height: height,
    fit: fit,
    fallbackAsset: fallbackAsset,
    semanticLabel: semanticLabel,
    blur: blur,
  );
}

// lib/core/widgets/movie_screenshot_image.dart
import 'package:flutter/material.dart';
import 'package:jade/core/providers/settings_provider.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:provider/provider.dart';

class MovieScreenshotImage extends StatelessWidget {
  const MovieScreenshotImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final blur = context.watch<SettingsProvider?>()?.blurMovieImages ?? true;
    return CachedImage(
      url,
      width: width,
      height: height,
      fit: fit,
      blur: blur,
    );
  }
}
```

- [ ] **Step 4: 运行组件测试并确认 GREEN**

Run: `flutter test test/core/widgets/movie_cover_image_test.dart test/core/widgets/movie_screenshot_image_test.dart`

Expected: PASS，封面和剧照均随 provider 更新。

- [ ] **Step 5: 提交影片图片组件接入**

```bash
git add lib/core/widgets/movie_cover_image.dart lib/core/widgets/movie_screenshot_image.dart test/core/widgets/movie_cover_image_test.dart test/core/widgets/movie_screenshot_image_test.dart
git commit -m "feat: apply blur setting to movie images"
```

### Task 4: 替换全部影片剧照入口

**Files:**
- Modify: `lib/core/widgets/movie_list_tile.dart`
- Modify: `lib/features/movie_detail/screens/movie_detail_screen.dart`
- Modify: `test/core/widgets/movie_card_test.dart`
- Modify: `test/features/movie_detail/movie_detail_screen_test.dart`

**Interfaces:**
- Consumes: `MovieScreenshotImage`。
- Produces: 列表内截图和详情页剧照不再直接实例化 `CachedImage`。

- [ ] **Step 1: 写调用方使用专用剧照组件的失败断言**

在现有 MovieListTile screenshots 测试中把数量断言改为：

```dart
expect(find.byType(MovieScreenshotImage), findsNWidgets(2));
```

在详情页顺序测试滚动到“预告片 / 剧照”后增加：

```dart
expect(find.byType(MovieScreenshotImage), findsOneWidget);
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/core/widgets/movie_card_test.dart test/features/movie_detail/movie_detail_screen_test.dart`

Expected: FAIL，两个调用方仍渲染 `CachedImage`。

- [ ] **Step 3: 替换两个剧照调用点**

```dart
// movie_list_tile.dart 和 movie_detail_screen.dart
import 'package:jade/core/widgets/movie_screenshot_image.dart';

// lib/core/widgets/movie_list_tile.dart
MovieScreenshotImage(screenshots![i])

// lib/features/movie_detail/screens/movie_detail_screen.dart
MovieScreenshotImage(urls[index])
```

保留现有尺寸、`AspectRatio`、`SizedBox` 和 `ClipRRect`，仅替换内部图片组件。

- [ ] **Step 4: 运行调用方测试并确认 GREEN**

Run: `flutter test test/core/widgets/movie_card_test.dart test/features/movie_detail/movie_detail_screen_test.dart`

Expected: PASS，列表截图和详情剧照均通过专用组件渲染。

- [ ] **Step 5: 提交剧照入口替换**

```bash
git add lib/core/widgets/movie_list_tile.dart lib/features/movie_detail/screens/movie_detail_screen.dart test/core/widgets/movie_card_test.dart test/features/movie_detail/movie_detail_screen_test.dart
git commit -m "feat: blur movie screenshots"
```

### Task 5: 在实际设置页添加开关

**Files:**
- Modify: `lib/features/profile/screens/profile_sub_pages.dart`
- Modify: `test/features/profile/profile_sub_pages_test.dart`

**Interfaces:**
- Consumes: `SettingsProvider.blurMovieImages`、`SettingsProvider.setBlurMovieImages(bool)`。
- Produces: 文案为“影片图片模糊”的 `SwitchListTile`。

- [ ] **Step 1: 写设置页交互 RED 测试**

```dart
testWidgets('设置页展示原设置项并切换持久化影片图片模糊', (tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = await SettingsProvider.create(prefs);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: const MaterialApp(home: ProfileSettingsPage()),
    ),
  );

  expect(find.text('影片图片模糊'), findsOneWidget);
  expect(find.text('外观模式'), findsOneWidget);
  expect(find.text('线路选择'), findsOneWidget);
  expect(find.text('默认筛选标签'), findsOneWidget);
  expect(find.text('清除缓存'), findsOneWidget);
  expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);

  await tester.tap(find.byType(SwitchListTile));
  await tester.pump();

  expect(settings.blurMovieImages, isFalse);
  expect(prefs.getBool(StorageKeys.blurMovieImages), isFalse);
});
```

- [ ] **Step 2: 运行测试并确认 RED**

Run: `flutter test test/features/profile/profile_sub_pages_test.dart`

Expected: FAIL，找不到“影片图片模糊”和 `SwitchListTile`。

- [ ] **Step 3: 在 ProfileSettingsPage 中添加开关**

```dart
import 'package:jade/core/providers/settings_provider.dart';
import 'package:provider/provider.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final blurMovieImages = context.select<SettingsProvider, bool>(
      (settings) => settings.blurMovieImages,
    );
    final cells = <Widget>[
      const _ProfileCell(
        title: '外观模式',
        subtitle: '跟随系统',
        icon: Icons.brightness_6_outlined,
      ),
      SwitchListTile(
        secondary: const Icon(Icons.blur_on_outlined),
        title: const Text('影片图片模糊'),
        subtitle: const Text('模糊影片封面与剧照'),
        value: blurMovieImages,
        onChanged: context.read<SettingsProvider>().setBlurMovieImages,
      ),
      const _ProfileCell(
        title: '线路选择',
        subtitle: '自动',
        icon: Icons.swap_horiz,
      ),
      const _ProfileCell(
        title: '默认筛选标签',
        subtitle: '含磁链',
        icon: Icons.tune,
      ),
      const _ProfileCell(
        title: '清除缓存',
        icon: Icons.cleaning_services_outlined,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView.separated(
        itemCount: cells.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) => cells[index],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行设置页测试并确认 GREEN**

Run: `flutter test test/features/profile/profile_sub_pages_test.dart`

Expected: PASS，原设置项和新增开关均正确显示，点击后持久化为 false。

- [ ] **Step 5: 提交设置页开关**

```bash
git add lib/features/profile/screens/profile_sub_pages.dart test/features/profile/profile_sub_pages_test.dart
git commit -m "feat: add movie image blur toggle"
```

### Task 6: 格式化、全量回归与设备验收

**Files:**
- Verify: all modified files

**Interfaces:**
- Consumes: Tasks 1-5 的完整实现。
- Produces: 可在 Android 设备上验证且通过完整回归的功能。

- [ ] **Step 1: 格式化全部修改的 Dart 文件**

Run:

```bash
dart format lib/core/storage/storage_keys.dart lib/core/providers/settings_provider.dart lib/core/widgets/cached_image.dart lib/core/widgets/movie_cover_image.dart lib/core/widgets/movie_screenshot_image.dart lib/core/widgets/movie_list_tile.dart lib/features/movie_detail/screens/movie_detail_screen.dart lib/features/profile/screens/profile_sub_pages.dart test/core/providers/settings_provider_test.dart test/core/widgets/cached_image_test.dart test/core/widgets/movie_cover_image_test.dart test/core/widgets/movie_screenshot_image_test.dart test/core/widgets/movie_card_test.dart test/features/movie_detail/movie_detail_screen_test.dart test/features/profile/profile_sub_pages_test.dart
```

Expected: formatter exits 0。

- [ ] **Step 2: 运行相关测试**

Run:

```bash
flutter test test/core/providers/settings_provider_test.dart test/core/widgets/cached_image_test.dart test/core/widgets/movie_cover_image_test.dart test/core/widgets/movie_screenshot_image_test.dart test/core/widgets/movie_card_test.dart test/features/movie_detail/movie_detail_screen_test.dart test/features/profile/profile_sub_pages_test.dart
```

Expected: 所有相关测试通过。

- [ ] **Step 3: 运行完整测试和静态分析**

Run: `flutter test`

Expected: `All tests passed!`

Run: `dart analyze`

Expected: `No issues found!`

- [ ] **Step 4: 通过 ADB 验收默认开启与切换效果**

Run: `flutter run`

检查：

1. 首页或影片列表 thumb 默认模糊。
2. 详情页 cover 和剧照默认模糊。
3. 设置页关闭“影片图片模糊”后返回，三类图片恢复清晰。
4. 使用 adb_tool 执行 `am force-stop xxx.porn.jdb` 后重新启动，关闭状态仍保留。
5. 再次开启后恢复模糊，演员头像和失败占位图始终清晰。

Expected: 五项设备检查全部满足，ADB 无 Flutter overflow 或崩溃日志。

- [ ] **Step 5: 检查最终差异并提交必要收尾**

Run: `git diff --check && git status --short`

Expected: `git diff --check` 无输出；若格式化未产生额外修改，工作区干净。
