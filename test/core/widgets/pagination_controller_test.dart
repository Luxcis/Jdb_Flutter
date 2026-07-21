import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/widgets/pagination_controller.dart';

void main() {
  test('fetchMore 捕获数据源异常并暴露 error，不向外抛出', () async {
    final controller = PaginationController<int>(
      fetch: (_) => throw StateError('bad page'),
    );

    await controller.fetchMore();

    expect(controller.error.toString(), contains('bad page'));
    expect(controller.isLoading, isFalse);
  });
}
