// lib/core/utils/time_format.dart

/// 将时间格式化为相对时间或完整日期。
///
/// - 1 小时内：`X分钟前`
/// - 24 小时内：`X小时前`
/// - 7 天内：`X天前`
/// - 更早：`YYYY-MM-DD hh:mm`
String formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// 解析 ISO 8601 字符串并格式化为相对时间；解析失败返回空串。
String formatIsoRelativeTime(String? iso) {
  if (iso == null) return '';
  final time = DateTime.tryParse(iso);
  if (time == null) return '';
  return formatRelativeTime(time.toLocal());
}
