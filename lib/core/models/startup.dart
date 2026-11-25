import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
part 'startup.g.dart';

/// 解密 backup_domains_data 后得到的域名配置实体。
///
/// JSON 键名使用 camelCase，与解密后的原始字段一一对应。
/// 所有字段均为容错解析：字段类型漂移只丢弃对应值，不会抛 TypeError。
@JsonSerializable(createToJson: false)
class BackupDomains {
  const BackupDomains({
    required this.apiDomains,
    this.backupUrls = const [],
    this.unblockedWebDomain,
    this.permanentWebDomain,
    this.unblockAppDomain,
    this.permanentAppDomain,
    this.imageEndpoint,
  });
  @JsonKey(fromJson: _stringListOrEmpty)
  final List<String> apiDomains;
  @JsonKey(fromJson: _stringListOrEmpty)
  final List<String> backupUrls;
  @JsonKey(fromJson: _stringOrNull)
  final String? unblockedWebDomain;
  @JsonKey(fromJson: _stringOrNull)
  final String? permanentWebDomain;
  @JsonKey(fromJson: _stringOrNull)
  final String? unblockAppDomain;
  @JsonKey(fromJson: _stringOrNull)
  final String? permanentAppDomain;
  @JsonKey(fromJson: _stringOrNull)
  final String? imageEndpoint;
  factory BackupDomains.fromJson(Map<String, dynamic> json) =>
      _$BackupDomainsFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class StartupData {
  const StartupData({
    this.backupDomainsData,
    this.recentKeywords = const [],
    this.recentMagnetKeywords = const [],
    this.settings,
    this.user,
  });
  @JsonKey(name: 'backup_domains_data', fromJson: _stringOrNull)
  final String? backupDomainsData;
  @JsonKey(name: 'recent_keywords', fromJson: _stringListOrEmpty)
  final List<String> recentKeywords;
  @JsonKey(name: 'recent_magnet_keywords', fromJson: _stringListOrEmpty)
  final List<String> recentMagnetKeywords;
  @JsonKey(fromJson: _mapOrNull)
  final Map<String, dynamic>? settings;
  @JsonKey(fromJson: _mapOrNull)
  final Map<String, dynamic>? user;
  factory StartupData.fromJson(Map<String, dynamic> json) =>
      _$StartupDataFromJson(json);
}

/// 容错解析字符串列表：跳过非字符串项，保留合法项。
List<String> _stringListOrEmpty(Object? value) {
  if (value is! List) {
    if (value != null) {
      debugPrint('StartupData: 列表字段类型异常（${value.runtimeType}），降级为空列表');
    }
    return const [];
  }
  final result = <String>[];
  for (final item in value) {
    if (item is String) {
      result.add(item);
    } else {
      debugPrint('StartupData: 跳过非字符串项（${item.runtimeType}）');
    }
  }
  return result;
}

/// 容错解析可选字符串：类型不符时降级为 null。
String? _stringOrNull(Object? value) {
  if (value == null || value is String) return value as String?;
  debugPrint('StartupData: 字符串字段类型异常（${value.runtimeType}），降级为 null');
  return null;
}

/// 容错解析可选对象：类型不符时降级为 null。
Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map<String, dynamic>(
      (key, entry) => MapEntry(key.toString(), entry),
    );
  }
  debugPrint('StartupData: 对象字段类型异常（${value.runtimeType}），降级为 null');
  return null;
}
