// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'startup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BackupDomains _$BackupDomainsFromJson(Map<String, dynamic> json) =>
    BackupDomains(
      apiDomains: (json['api_domains'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      backupUrls:
          (json['backup_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      unblockedAppDomain: json['unblocked_app_domain'] as String?,
      permanentAppDomain: json['permanent_app_domain'] as String?,
      imageEndpoint: json['image_endpoint'] as String?,
    );

Map<String, dynamic> _$BackupDomainsToJson(BackupDomains instance) =>
    <String, dynamic>{
      'api_domains': instance.apiDomains,
      'backup_urls': instance.backupUrls,
      'unblocked_app_domain': instance.unblockedAppDomain,
      'permanent_app_domain': instance.permanentAppDomain,
      'image_endpoint': instance.imageEndpoint,
    };

StartupData _$StartupDataFromJson(Map<String, dynamic> json) => StartupData(
  backupDomainsData: json['backup_domains_data'] as String?,
  settings: json['settings'] as Map<String, dynamic>?,
  user: json['user'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$StartupDataToJson(StartupData instance) =>
    <String, dynamic>{
      'backup_domains_data': instance.backupDomainsData,
      'settings': instance.settings,
      'user': instance.user,
    };
