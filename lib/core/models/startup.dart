import 'package:json_annotation/json_annotation.dart';
part 'startup.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class BackupDomains {
  const BackupDomains({
    required this.apiDomains,
    this.backupUrls = const [],
    this.unblockedAppDomain,
    this.permanentAppDomain,
    this.imageEndpoint,
  });
  final List<String> apiDomains;
  final List<String> backupUrls;
  final String? unblockedAppDomain;
  final String? permanentAppDomain;
  final String? imageEndpoint;
  factory BackupDomains.fromJson(Map<String, dynamic> json) =>
      _$BackupDomainsFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class StartupData {
  const StartupData({this.backupDomainsData, this.settings, this.user});
  final String? backupDomainsData;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? user;
  factory StartupData.fromJson(Map<String, dynamic> json) =>
      _$StartupDataFromJson(json);
}
