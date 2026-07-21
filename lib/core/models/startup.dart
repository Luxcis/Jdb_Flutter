import 'package:json_annotation/json_annotation.dart';
part 'startup.g.dart';

/// 解密 backup_domains_data 后得到的域名配置实体。
///
/// JSON 键名使用 camelCase，与解密后的原始字段一一对应。
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
  final List<String> apiDomains;
  final List<String> backupUrls;
  final String? unblockedWebDomain;
  final String? permanentWebDomain;
  final String? unblockAppDomain;
  final String? permanentAppDomain;
  final String? imageEndpoint;
  factory BackupDomains.fromJson(Map<String, dynamic> json) =>
      _$BackupDomainsFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class StartupData {
  const StartupData({this.backupDomainsData, this.settings, this.user});
  final String? backupDomainsData;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? user;
  factory StartupData.fromJson(Map<String, dynamic> json) =>
      _$StartupDataFromJson(json);
}
