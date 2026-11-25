// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'startup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BackupDomains _$BackupDomainsFromJson(Map<String, dynamic> json) =>
    BackupDomains(
      apiDomains: _stringListOrEmpty(json['apiDomains']),
      backupUrls: _stringListOrEmpty(json['backupUrls']),
      unblockedWebDomain: _stringOrNull(json['unblockedWebDomain']),
      permanentWebDomain: _stringOrNull(json['permanentWebDomain']),
      unblockAppDomain: _stringOrNull(json['unblockAppDomain']),
      permanentAppDomain: _stringOrNull(json['permanentAppDomain']),
      imageEndpoint: _stringOrNull(json['imageEndpoint']),
    );

StartupData _$StartupDataFromJson(Map<String, dynamic> json) => StartupData(
  backupDomainsData: _stringOrNull(json['backup_domains_data']),
  recentKeywords: _stringListOrEmpty(json['recent_keywords']),
  recentMagnetKeywords: _stringListOrEmpty(json['recent_magnet_keywords']),
  settings: _mapOrNull(json['settings']),
  user: _mapOrNull(json['user']),
);
