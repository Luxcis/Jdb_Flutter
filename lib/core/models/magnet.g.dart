// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'magnet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Magnet _$MagnetFromJson(Map<String, dynamic> json) => Magnet(
  hash: json['hash'] as String,
  title: json['title'] as String?,
  size: json['size'] as String?,
  publishDate: json['publish_date'] as String?,
  isHighDefinition: json['is_high_definition'] as bool? ?? false,
);
