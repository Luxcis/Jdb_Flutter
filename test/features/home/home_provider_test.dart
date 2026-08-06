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
  int recommendCalls = 0;
  Object? recommendError;
  Object? latestError;
  Object? magnetError;
  Completer<void>? latestGate;

  @override
  Future<List<MovieSummary>> getRecommends({String? period}) async {
    recommendCalls++;
    if (recommendError case final error?) throw error;
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
    expect(provider.latest.items.single.id, 'latest-3');
    expect(provider.magnetUpdates.items.single.id, 'magnet-2');
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
    expect(provider.latest.items.single.id, 'latest-1');
    service.latestError = null;
    await provider.reshuffleLatest();
    expect(service.latestPages, [1, 2, 2]);
    expect(provider.latestPage, 2);
  });

  test('三个分区独立加载，一个挂起不影响其它分区', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    service.latestGate = Completer<void>();

    final load = provider.loadAll();
    await Future<void>.delayed(Duration.zero);

    expect(provider.recommends.isLoading, isFalse);
    expect(provider.recommends.items.single.id, 'recommend');
    expect(provider.latest.isLoading, isTrue);
    expect(provider.latest.error, isNull);
    expect(provider.magnetUpdates.isLoading, isFalse);
    expect(provider.magnetUpdates.items.single.id, 'magnet-1');

    service.latestGate!.complete();
    await load;
    expect(provider.latest.isLoading, isFalse);
    expect(provider.latest.items.single.id, 'latest-1');
  });

  test('单分区首次加载失败不影响其它分区', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    service.latestError = StateError('network');

    await provider.loadAll();

    expect(provider.latest.isLoading, isFalse);
    expect(provider.latest.error, isNotNull);
    expect(provider.latest.items, isEmpty);
    expect(provider.recommends.items.single.id, 'recommend');
    expect(provider.magnetUpdates.items.single.id, 'magnet-1');
  });

  test('retrySection 只重发失败分区并清除错误', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    service.latestError = StateError('network');
    await provider.loadAll();
    expect(provider.latest.error, isNotNull);

    service.latestError = null;
    await provider.retrySection(HomeSectionKind.latest);

    expect(provider.latest.error, isNull);
    expect(provider.latest.items.single.id, 'latest-1');
    expect(service.latestPages, [1, 1]);
    expect(service.magnetPages, [1]);
    expect(provider.latestPage, 1);
  });

  test('重试推荐分区只重新请求推荐接口', () async {
    final service = _FakeHomeService();
    final provider = HomeProvider(service);
    service.recommendError = StateError('network');
    await provider.loadAll();
    expect(provider.recommends.error, isNotNull);

    service.recommendError = null;
    await provider.retrySection(HomeSectionKind.recommends);

    expect(provider.recommends.error, isNull);
    expect(provider.recommends.items.single.id, 'recommend');
    expect(service.recommendCalls, 2);
    expect(service.latestPages, [1]);
    expect(service.magnetPages, [1]);
  });
}
