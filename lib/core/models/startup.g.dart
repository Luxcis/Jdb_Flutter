// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'startup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BackupDomains _$BackupDomainsFromJson(Map<String, dynamic> json) =>
    BackupDomains(
      apiDomains: (json['apiDomains'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      backupUrls:
          (json['backupUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      unblockedWebDomain: json['unblockedWebDomain'] as String?,
      permanentWebDomain: json['permanentWebDomain'] as String?,
      unblockAppDomain: json['unblockAppDomain'] as String?,
      permanentAppDomain: json['permanentAppDomain'] as String?,
      imageEndpoint: json['imageEndpoint'] as String?,
    );

StartupData _$StartupDataFromJson(Map<String, dynamic> json) => StartupData(
  backupDomainsData: json['backup_domains_data'] as String?,
  settings: json['settings'] as Map<String, dynamic>?,
  user: json['user'] as Map<String, dynamic>?,
);
