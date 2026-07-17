// lib/core/network/domain_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jade/core/constants/app_constants.dart';
import 'package:jade/core/models/startup.dart';
import 'package:jade/core/storage/storage_keys.dart';

/// 域名动态切换状态机。参见 spec §3.3。
class DomainManager extends ChangeNotifier {
  DomainManager._({required SharedPreferences prefs}) : _prefs = prefs {
    _currentUrl = AppConstants.defaultBaseUrl;
    _apiDomains = const [];
  }

  final SharedPreferences _prefs;

  late String _currentUrl;
  List<String> _apiDomains = const [];
  int _index = 0;

  String get currentUrl => _currentUrl;
  List<String> get apiDomains => List.unmodifiable(_apiDomains);
  bool get isOnMainDomain => _currentUrl == AppConstants.mainDomain;

  /// 启动加载：SP 有则恢复，否则默认 staging。
  static Future<DomainManager> load(SharedPreferences prefs) async {
    final dm = DomainManager._(prefs: prefs);
    final stored = prefs.getStringList(StorageKeys.apiDomains);
    final url = prefs.getString(StorageKeys.baseUrl);
    if (stored != null && stored.isNotEmpty) {
      dm._apiDomains = List<String>.from(stored);
      dm._index = 0;
      dm._currentUrl = url ?? stored.first;
    } else {
      dm._currentUrl = url ?? AppConstants.defaultBaseUrl;
    }
    return dm;
  }

  /// 写入 startup 接口返回的域名列表，主域名落首位并持久化。
  Future<void> applyStartup(BackupDomains data) async {
    _apiDomains = List<String>.from(data.apiDomains);
    _index = 0;
    _currentUrl = _apiDomains.isNotEmpty ? _apiDomains.first : _currentUrl;
    await _persist();
    notifyListeners();
  }

  /// 轮转到下一个备用域名。返回 false 表示无可用备用域名。
  Future<bool> rotate() async {
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
