import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/utils/time_format.dart';

void main() {
  group('formatRelativeTime', () {
    test('1 小时内显示 X分钟前', () {
      final time = DateTime.now().subtract(const Duration(minutes: 5));
      expect(formatRelativeTime(time), matches(RegExp(r'^\d+分钟前$')));
    });

    test('24 小时内显示 X小时前', () {
      final time = DateTime.now().subtract(const Duration(hours: 5));
      expect(formatRelativeTime(time), matches(RegExp(r'^\d+小时前$')));
    });

    test('7 天内显示 X天前', () {
      final time = DateTime.now().subtract(const Duration(days: 2));
      expect(formatRelativeTime(time), matches(RegExp(r'^\d+天前$')));
    });

    test('超过 7 天显示 YYYY-MM-DD hh:mm', () {
      final time = DateTime.now().subtract(const Duration(days: 10));
      expect(
        formatRelativeTime(time),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')),
      );
    });
  });

  group('formatIsoRelativeTime', () {
    test('null 返回空串', () {
      expect(formatIsoRelativeTime(null), '');
    });

    test('非法字符串返回空串', () {
      expect(formatIsoRelativeTime('not-a-date'), '');
    });

    test('UTC ISO 字符串转换为本地相对时间', () {
      final iso = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 10))
          .toIso8601String();
      expect(formatIsoRelativeTime(iso), matches(RegExp(r'^\d+分钟前$')));
    });
  });
}
