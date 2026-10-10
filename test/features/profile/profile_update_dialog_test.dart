import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/profile/services/update_service.dart';
import 'package:jade/features/profile/widgets/profile_update_dialog.dart';

UpdateCheckResult _buildResult() {
  final release = GitHubRelease(
    tagName: 'v0.10.0',
    body: '- fix: something',
    assets: [
      const GitHubReleaseAsset(
        name: 'app-arm64-v8a-release.apk',
        size: 100,
        downloadUrl: 'https://example.com/app.apk',
      ),
    ],
  );
  return UpdateCheckResult(
    release: release,
    hasUpdate: true,
    latestVersion: '0.10.0',
  );
}

/// 通过外层「打开」按钮弹出 UpdateDialog，展开完整交互状态机。
Future<void> _pumpDialog(
  WidgetTester tester, {
  Future<String> Function(
    UpdateCheckResult result,
    void Function(int received, int total) onProgress,
  )?
  download,
  required Future<ApkInstallOutcome> Function(String apkPath) install,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => UpdateDialog(
                    result: _buildResult(),
                    download:
                        download ??
                        (result, onProgress) async => '/tmp/app.apk',
                    install: install,
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('下载完成后自动触发安装流程，无需点击「安装」', (tester) async {
    var installCalls = 0;

    await _pumpDialog(
      tester,
      install: (path) async {
        installCalls++;
        return ApkInstallOutcome.opened;
      },
    );

    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('安装'), findsNothing);
    expect(find.text('下载完成，点击「安装」可开始更新'), findsNothing);

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(installCalls, 1, reason: '下载完成后自动触发安装编排，无需用户点击');
    expect(find.text('下载完成，点击「安装」可开始更新'), findsNothing, reason: '成功路径不出现等待点击的完成态');
    expect(find.text('发现新版本 0.10.0'), findsNothing, reason: '校验通过并调起安装器后弹窗关闭');
  });

  testWidgets('下载过程展示进度并提示下载失败可重试', (tester) async {
    final downloadGate = Completer<String>();
    var downloaded = false;
    var installCalls = 0;

    await _pumpDialog(
      tester,
      download: (result, onProgress) async {
        onProgress(50, 100);
        await downloadGate.future;
        downloaded = true;
        return '/tmp/app.apk';
      },
      install: (path) async {
        installCalls++;
        return ApkInstallOutcome.opened;
      },
    );

    await tester.tap(find.text('立即更新'));
    await tester.pump();
    expect(find.text('正在下载更新… 50%'), findsOneWidget, reason: '进度百分比按回调值展示');

    downloadGate.complete('/tmp/app.apk');
    await tester.pumpAndSettle();
    expect(downloaded, isTrue);
    expect(installCalls, 1, reason: '下载完成后自动触发安装编排并关闭弹窗');
    expect(find.text('发现新版本 0.10.0'), findsNothing);
  });

  testWidgets('弹窗已关闭时不自动安装', (tester) async {
    final downloadGate = Completer<String>();
    var installCalls = 0;

    await _pumpDialog(
      tester,
      download: (result, onProgress) async {
        await downloadGate.future;
        return '/tmp/app.apk';
      },
      install: (path) async {
        installCalls++;
        return ApkInstallOutcome.opened;
      },
    );

    await tester.tap(find.text('立即更新'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    downloadGate.complete('/tmp/app.apk');
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(installCalls, 0, reason: '弹窗已卸载，不自动触发校验与安装');
  });

  testWidgets('下载完成后自动进入校验中状态且不重复触发，通过后关闭弹窗', (tester) async {
    final installGate = Completer<ApkInstallOutcome>();
    var installCalls = 0;

    await _pumpDialog(
      tester,
      install: (path) async {
        installCalls++;
        return installGate.future;
      },
    );

    await tester.tap(find.text('立即更新'));
    await tester.pump();
    await tester.pump();

    expect(find.text('正在校验安装包完整性…'), findsOneWidget);
    expect(find.text('校验中…'), findsOneWidget);
    expect(find.text('下载完成，点击「安装」可开始更新'), findsNothing, reason: '自动流程没有等待点击的完成态');
    expect(find.text('安装'), findsNothing, reason: '校验中不提供「安装」按钮');
    expect(installCalls, 1);

    // 校验期间按钮禁用，重复点击不会再次触发。
    await tester.tap(find.text('校验中…'));
    await tester.pump();
    expect(installCalls, 1);

    installGate.complete(ApkInstallOutcome.opened);
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 0.10.0'), findsNothing, reason: '调起安装器后弹窗关闭');
  });

  testWidgets('自动校验不一致提示失败并可重新下载，重下后再次自动校验', (tester) async {
    var installCalls = 0;
    final secondPassGate = Completer<ApkInstallOutcome>();

    await _pumpDialog(
      tester,
      install: (path) async {
        installCalls++;
        return installCalls == 1
            ? ApkInstallOutcome.hashMismatch
            : secondPassGate.future;
      },
    );

    await tester.tap(find.text('立即更新'));
    await tester.pump();
    await tester.pump();

    expect(installCalls, 1);
    expect(find.text('安装包校验失败，已阻止安装'), findsOneWidget);
    expect(find.text('重新下载'), findsOneWidget);
    expect(find.text('安装'), findsNothing);

    await tester.tap(find.text('重新下载'));
    await tester.pump();
    await tester.pump();

    expect(installCalls, 2, reason: '重新下载完成后再次自动进入校验');
    expect(find.text('正在校验安装包完整性…'), findsOneWidget);

    secondPassGate.complete(ApkInstallOutcome.opened);
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 0.10.0'), findsNothing, reason: '再次校验通过并调起安装器后弹窗关闭');
  });

  testWidgets('无法校验提示阻止安装且保留重试入口', (tester) async {
    var installCalls = 0;

    await _pumpDialog(
      tester,
      install: (path) async {
        installCalls++;
        return ApkInstallOutcome.hashUnavailable;
      },
    );

    await tester.tap(find.text('立即更新'));
    await tester.pump();
    await tester.pump();

    expect(installCalls, 1, reason: '下载完成后自动完成校验');
    expect(find.text('无法校验安装包完整性，已阻止安装'), findsOneWidget);
    expect(find.text('安装'), findsOneWidget, reason: '文件保留，允许手动重试校验');
    expect(find.text('重新下载'), findsNothing);
  });

  testWidgets('系统安装器调起失败保持既有降级提示', (tester) async {
    await _pumpDialog(
      tester,
      install: (path) async => ApkInstallOutcome.openFailed,
    );

    await tester.tap(find.text('立即更新'));
    await tester.pump();
    await tester.pump();

    expect(find.text('安装包已下载，请在通知栏/文件管理器中安装'), findsOneWidget);
    expect(find.text('安装'), findsOneWidget);
  });

  testWidgets('下载失败提示并可重新下载', (tester) async {
    var installCalls = 0;

    await _pumpDialog(
      tester,
      download: (result, onProgress) async => throw Exception('network'),
      install: (path) async {
        installCalls++;
        return ApkInstallOutcome.opened;
      },
    );

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(find.text('下载失败，请重试'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget, reason: '下载失败可重试');
    expect(installCalls, 0, reason: '下载失败不触发安装编排');
  });

  testWidgets('校验通过路径不显示失败提示', (tester) async {
    final installedPaths = <String>[];

    await _pumpDialog(
      tester,
      install: (path) async {
        installedPaths.add(path);
        return ApkInstallOutcome.opened;
      },
    );

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(installedPaths, ['/tmp/app.apk'], reason: '自动编排收到下载完成的文件路径');
    expect(find.text('安装包校验失败，已阻止安装'), findsNothing);
    expect(find.text('无法校验安装包完整性，已阻止安装'), findsNothing);
  });
}
