import 'package:jade/core/network/api_data.dart';

/// 标签关注项，对应 API 的 FollowTagItem / 关注返回的 data 对象。
class FollowTagItem {
  const FollowTagItem({
    required this.id,
    required this.name,
    required this.value,
    this.priority,
  });

  /// 标签 id（openapi 标为 int，统一存 String 便于缓存与 DELETE 路径拼接）。
  final String id;

  /// 已选中标签名称，用 ',' 拼接。
  final String name;

  /// filter_by 片段（也作为 /api/v1/movies/tags 的 filter_by 参数值）。
  final String value;

  /// 优先级权重（可空）。
  final num? priority;

  factory FollowTagItem.fromJson(Map<String, dynamic> json) => FollowTagItem(
    id: (json['id'] ?? '').toString(),
    name: apiString(json['name']) ?? '',
    value: apiString(json['value']) ?? '',
    priority: json['priority'] is num ? (json['priority'] as num?) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'value': value,
    if (priority != null) 'priority': priority,
  };
}
