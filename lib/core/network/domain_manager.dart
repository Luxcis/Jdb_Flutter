// lib/core/network/domain_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/storage/storage_keys.dart';

/// 线路模式：自动（608 自动轮转）或手动（固定域名，禁用轮转）。
enum LineMode { auto, manual }

/// 域名动态切换状态机。
///
/// 从 startup API 解密 [BackupDomains] 后写入，同时管理 API 域名轮转和 CDN 端点。
///
/// 所有来自外部（持久化存储或服务端下发）的域名都必须先通过
/// [isValidBaseUrl] 校验，避免把 Bearer Token 发往非 https 或空主机地址。
class DomainManager extends ChangeNotifier {
  DomainManager._({required SharedPreferences prefs}) : _prefs = prefs {
    _currentUrl = AppConstants.fallbackBaseUrl;
    _apiDomains = const [];
  }

  final SharedPreferences _prefs;

  late String _currentUrl;
  List<String> _apiDomains = const [];
  List<String> _backupUrls = const [];
  String? _permanentAppDomain;
  String? _unblockAppDomain;
  int _index = 0;
  String? _imageEndpoint;
  LineMode _lineMode = LineMode.auto;

  /// 当前 API base URL。
  String get currentUrl => _currentUrl;

  /// 当前 API 域名列表（仅包含通过校验的 https 地址）。
  List<String> get apiDomains => List.unmodifiable(_apiDomains);

  /// 图片 CDN 端点，优先来自 startup，否则使用兜底值。
  String get imageEndpoint => _imageEndpoint ?? AppConstants.fallbackImageCdn;

  /// 当前线路模式。
  LineMode get lineMode => _lineMode;

  /// 是否自动线路模式。
  bool get isAutoMode => _lineMode == LineMode.auto;

  /// 是否位于主域名（列表第一个，即 startup 返回的首个 apiDomain）。
  bool get isOnMainDomain =>
      _apiDomains.isNotEmpty && _currentUrl == _apiDomains.first;

  /// 启动阶段候选线路：当前线路 → 持久化/下发的 apiDomains →
  /// 备用域名（backupUrls/permanentAppDomain/unblockAppDomain）→ 兜底域名。
  ///
  /// 返回值已过滤不合规条目并去重，顺序即推荐尝试顺序；第一个总是当前线路，
  /// 因此启动重试会从本地持久化的可用线路开始。
  List<String> get candidateBaseUrls => List.unmodifiable(
    validBaseUrls([
      _currentUrl,
      ..._apiDomains,
      ..._backupUrls,
      ?_permanentAppDomain,
      ?_unblockAppDomain,
      AppConstants.fallbackBaseUrl,
    ]),
  );

  /// 判断 [value] 是否为可安全使用的 API 线路地址：可解析、scheme 为 https、
  /// host 非空。
  static bool isValidBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    return uri.host.isNotEmpty;
  }

  /// 过滤 [values] 中不合规的域名（记录日志）并按首次出现顺序去重。
  static List<String> validBaseUrls(Iterable<String> values) {
    final result = <String>[];
    for (final value in values) {
      if (!isValidBaseUrl(value)) {
        debugPrint('DomainManager: 丢弃不合规域名 "$value"（要求 https 且 host 非空）');
        continue;
      }
      if (!result.contains(value)) {
        result.add(value);
      }
    }
    return result;
  }

  /// 启动加载：SP 有则恢复，否则使用兜底域名。
  ///
  /// 持久化内容可能来自旧版本或被改写，因此恢复前逐项校验；不合规条目丢弃
  /// 并记录日志，不参与 baseUrl 选择。
  static Future<DomainManager> load(SharedPreferences prefs) async {
    final dm = DomainManager._(prefs: prefs);
    final stored = validBaseUrls(
      prefs.getStringList(StorageKeys.apiDomains) ?? const [],
    );
    final storedUrl = prefs.getString(StorageKeys.baseUrl);
    final url = _validOrNull(storedUrl);
    final line = prefs.getString(StorageKeys.line);
    if (stored.isNotEmpty) {
      dm._apiDomains = stored;
      final restoredIndex = url == null ? -1 : stored.indexOf(url);
      dm._index = restoredIndex < 0 ? 0 : restoredIndex;
      dm._currentUrl = url ?? stored.first;
    } else {
      dm._currentUrl = url ?? AppConstants.fallbackBaseUrl;
    }
    if (line != null && line != 'auto') {
      if (isValidBaseUrl(line)) {
        dm._lineMode = LineMode.manual;
        dm._currentUrl = line;
      } else {
        debugPrint('DomainManager: 忽略不合规的手动线路 "$line"');
      }
    }
    return dm;
  }

  /// 写入 startup 接口返回的域名列表，保持手动选择或回退自动。
  ///
  /// 本次下发的 apiDomains 全部不合规时保持当前 baseUrl 与历史域名列表不变，
  /// 避免一份坏响应把仍然可用的线路清空。
  Future<void> applyStartup(BackupDomains data) async {
    final previousUrl = _currentUrl;
    final wasManual = _lineMode == LineMode.manual;
    final domains = validBaseUrls(data.apiDomains);
    if (domains.isEmpty) {
      // 下发内容不可信：连备用域名一并忽略，整体保持当前状态。
      debugPrint('DomainManager: startup 未下发合规域名，保持当前线路 $previousUrl');
      return;
    }
    _backupUrls = validBaseUrls(data.backupUrls);
    _permanentAppDomain = _validOrNull(data.permanentAppDomain);
    _unblockAppDomain = _validOrNull(data.unblockAppDomain);
    _apiDomains = domains;
    _index = 0;
    if (wasManual && _apiDomains.contains(previousUrl)) {
      _currentUrl = previousUrl;
      _index = _apiDomains.indexOf(previousUrl);
    } else {
      _lineMode = LineMode.auto;
      _currentUrl = _apiDomains.first;
      await _prefs.setString(StorageKeys.line, 'auto');
    }
    _imageEndpoint = data.imageEndpoint;
    await _persist();
    notifyListeners();
  }

  /// 手动选择固定线路域名。不合规地址会被拒绝且不改变当前状态。
  Future<void> select(String url) async {
    if (!isValidBaseUrl(url)) {
      debugPrint('DomainManager: 拒绝切换到不合规域名 "$url"');
      return;
    }
    _lineMode = LineMode.manual;
    _currentUrl = url;
    await _prefs.setString(StorageKeys.line, url);
    await _persist();
    notifyListeners();
  }

  /// 恢复自动线路并切回主域名。
  Future<void> selectAuto() async {
    _lineMode = LineMode.auto;
    if (_apiDomains.isNotEmpty) {
      _currentUrl = _apiDomains.first;
      _index = 0;
    }
    await _prefs.setString(StorageKeys.line, 'auto');
    await _persist();
    notifyListeners();
  }

  /// 轮转到下一个备用域名。返回 false 表示无可用备用域名或手动模式。
  Future<bool> rotate() async {
    if (_lineMode == LineMode.manual) return false;
    if (_apiDomains.length <= 1) return false;
    _index = (_index + 1) % _apiDomains.length;
    _currentUrl = _apiDomains[_index];
    await _persist();
    notifyListeners();
    return true;
  }

  /// 校验可选域名：null 或不合规时返回 null（并记录日志）。
  static String? _validOrNull(String? value) {
    if (value == null) return null;
    if (isValidBaseUrl(value)) return value;
    debugPrint('DomainManager: 丢弃不合规域名 "$value"（要求 https 且 host 非空）');
    return null;
  }

  Future<void> _persist() async {
    await _prefs.setString(StorageKeys.baseUrl, _currentUrl);
    await _prefs.setStringList(StorageKeys.apiDomains, _apiDomains);
  }
}
