import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_brightness.dart';

void main() {
  group('FakeMoviePreviewBrightnessController', () {
    test('返回初始亮度并记录设置值', () async {
      final controller = FakeMoviePreviewBrightnessController(initial: 0.3);

      expect(await controller.current, 0.3);

      await controller.setBrightness(0.8);
      expect(await controller.current, 0.8);
      expect(controller.setValues, [0.8]);

      await controller.setBrightness(1.5);
      expect(await controller.current, 1.0);
      expect(controller.setValues, [0.8, 1.0]);

      await controller.setBrightness(-0.2);
      expect(await controller.current, 0.0);
    });

    test('reset 只增加调用计数', () async {
      final controller = FakeMoviePreviewBrightnessController();

      await controller.reset();
      expect(controller.resetCalls, 1);
    });

    test('注入错误时抛出异常', () async {
      final controller = FakeMoviePreviewBrightnessController()
        ..error = Exception('brightness failed');

      expect(controller.setBrightness(0.5), throwsException);
    });
  });
}
