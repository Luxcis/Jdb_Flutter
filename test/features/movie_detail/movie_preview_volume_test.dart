import 'package:flutter_test/flutter_test.dart';
import 'package:jade/features/movie_detail/services/movie_preview_volume.dart';

void main() {
  group('FakeMoviePreviewVolumeController', () {
    test('返回初始音量并记录设置值', () async {
      final controller = FakeMoviePreviewVolumeController(initial: 0.4);

      expect(await controller.current, 0.4);

      await controller.setVolume(0.9);
      expect(await controller.current, 0.9);
      expect(controller.setValues, [0.9]);

      await controller.setVolume(2.0);
      expect(await controller.current, 1.0);
      expect(controller.setValues, [0.9, 1.0]);

      await controller.setVolume(-1.0);
      expect(await controller.current, 0.0);
    });

    test('注入错误时抛出异常', () async {
      final controller = FakeMoviePreviewVolumeController()
        ..error = Exception('volume failed');

      expect(controller.setVolume(0.5), throwsException);
    });
  });
}
