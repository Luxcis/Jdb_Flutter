import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/home/providers/home_provider.dart';
import 'package:jade/features/home/services/home_service.dart';

const _recommend = MovieSummary(
  id: 'recommend',
  number: 'R-1',
  title: 'Recommend',
  coverUrl: 'recommend.jpg',
);

MovieSummary _movie(String id) =>
    MovieSummary(id: id, number: id, title: id, coverUrl: '$id.jpg');

class _FakeHomeService implements HomeService {
  final latestPages = <int>[];
  final magnetPages = <int>[];
  Object? latestError;
  Object? magnetError;
  Completer<void>? latestGate;

  @override
  Future<List<MovieSummary>> getRecommends({String? period}) async {
    return const [_recommend];
  }

  @override
  Future<List<String>> getRecommendPeriods() async => const [];

  @override
  Future<List<MovieSummary>> getLatest({int page = 1, int limit = 9}) async {
    latestPages.add(page);
    if (latestGate case final gate?) await gate.future;
    if (latestError case final error?) throw error;
    return [_movie('latest-$page')];
  }

  @override
  Future<List<MovieSummary>> getMagnetUpdates({
    int page = 1,
    int limit = 9,
  }) async {
    magnetPages.add(page);
    if (magnetError case final error?) throw error;
    return [_movie('magnet-$page')];
  }
}

void main() {
  test('两个首页分区从第 1 页开始并独立递增', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);

    await provider.loadAll();
    await provider.reshuffleLatest();
    await provider.reshuffleLatest();
    await provider.reshuffleMagnets();

    expect(service.latestPages, [1, 2, 3]);
    expect(service.magnetPages, [1, 2]);
    expect(provider.latestPage, 3);
    expect(provider.magnetPage, 2);
    expect(provider.latest.single.id, 'latest-3');
    expect(provider.magnetUpdates.single.id, 'magnet-2');
  });

  test('最新上架换组加载期间阻止重复请求', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    await provider.loadAll();
    service.latestGate = Completer<void>();

    final first = provider.reshuffleLatest();
    final duplicate = provider.reshuffleLatest();

    expect(provider.isLatestRefreshing, isTrue);
    expect(service.latestPages, [1, 2]);
    service.latestGate!.complete();
    await Future.wait([first, duplicate]);
    expect(provider.isLatestRefreshing, isFalse);
  });

  test('换组失败保留当前页和影片并允许重试同一下一页', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    await provider.loadAll();
    service.latestError = StateError('network');

    await expectLater(provider.reshuffleLatest(), throwsStateError);

    expect(provider.latestPage, 1);
    expect(provider.latest.single.id, 'latest-1');
    service.latestError = null;
    await provider.reshuffleLatest();
    expect(service.latestPages, [1, 2, 2]);
    expect(provider.latestPage, 2);
  });
}
