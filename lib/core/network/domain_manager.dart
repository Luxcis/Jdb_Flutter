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
class DomainManager extends ChangeNotifier {
  DomainManager._({required SharedPreferences prefs}) : _prefs = prefs {
    _currentUrl = AppConstants.fallbackBaseUrl;
    _apiDomains = const [];
  }

  final SharedPreferences _prefs;

  late String _currentUrl;
  List<String> _apiDomains = const [];
  int _index = 0;
  String? _imageEndpoint;
  LineMode _lineMode = LineMode.auto;

  /// 当前 API base URL。
  String get currentUrl => _currentUrl;

  /// 当前 API 域名列表。
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

  /// 启动加载：SP 有则恢复，否则使用兜底域名。
  static Future<DomainManager> load(SharedPreferences prefs) async {
    final dm = DomainManager._(prefs: prefs);
    final stored = prefs.getStringList(StorageKeys.apiDomains);
    final url = prefs.getString(StorageKeys.baseUrl);
    final line = prefs.getString(StorageKeys.line);
    if (stored != null && stored.isNotEmpty) {
      dm._apiDomains = List<String>.from(stored);
      dm._index = 0;
      dm._currentUrl = url ?? stored.first;
    } else {
      dm._currentUrl = url ?? AppConstants.fallbackBaseUrl;
    }
    if (line != null && line != 'auto') {
      dm._lineMode = LineMode.manual;
      dm._currentUrl = line;
    }
    return dm;
  }

  /// 写入 startup 接口返回的域名列表，保持手动选择或回退自动。
  Future<void> applyStartup(BackupDomains data) async {
    final previousUrl = _currentUrl;
    final wasManual = _lineMode == LineMode.manual;
    _apiDomains = List<String>.from(data.apiDomains);
    _index = 0;
    if (wasManual && _apiDomains.contains(previousUrl)) {
      _currentUrl = previousUrl;
    } else {
      _lineMode = LineMode.auto;
      _currentUrl = _apiDomains.isNotEmpty ? _apiDomains.first : _currentUrl;
      await _prefs.setString(StorageKeys.line, 'auto');
    }
    _imageEndpoint = data.imageEndpoint;
    await _persist();
    notifyListeners();
  }

  /// 手动选择固定线路域名。
  Future<void> select(String url) async {
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

  Future<void> _persist() async {
    await _prefs.setString(StorageKeys.baseUrl, _currentUrl);
    await _prefs.setStringList(StorageKeys.apiDomains, _apiDomains);
  }
}
