import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/profile/services/update_check_session.dart';

void main() {
  group('UpdateCheckSession', () {
    test('初始状态为未检查', () {
      final session = UpdateCheckSession();
      expect(session.status, UpdateCheckStatus.none);
    });

    test('记录无更新结论后状态为 upToDate', () {
      final session = UpdateCheckSession();
      session.record(false);
      expect(session.status, UpdateCheckStatus.upToDate);
    });

    test('记录有更新结论后状态为 hasUpdate', () {
      final session = UpdateCheckSession();
      session.record(true);
      expect(session.status, UpdateCheckStatus.hasUpdate);
    });

    test('新结论覆盖旧结论', () {
      final session = UpdateCheckSession();
      session.record(false);
      session.record(true);
      expect(session.status, UpdateCheckStatus.hasUpdate);

      session.record(false);
      expect(session.status, UpdateCheckStatus.upToDate);
    });

    test('状态变化时通知监听者，相同结论不重复通知', () {
      final session = UpdateCheckSession();
      var notifications = 0;
      session.addListener(() => notifications++);

      session.record(false);
      session.record(false);
      expect(notifications, 1);

      session.record(true);
      expect(notifications, 2);
    });
  });
}
