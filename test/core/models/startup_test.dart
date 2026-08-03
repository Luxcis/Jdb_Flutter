import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/startup.dart';

void main() {
  test('解析 recent_keywords 字符串列表', () {
    final startup = StartupData.fromJson({
      'recent_keywords': ['演员', 'ABP-001'],
    });

    expect(startup.recentKeywords, ['演员', 'ABP-001']);
  });

  test('缺少 recent_keywords 时默认为空列表', () {
    expect(StartupData.fromJson(const {}).recentKeywords, isEmpty);
  });
}
