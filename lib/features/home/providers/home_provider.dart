import 'package:flutter/foundation.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/home/services/home_service.dart';

/// 首页分区标识。
enum HomeSectionKind { recommends, latest, magnets }

/// 单个分区的数据与加载状态。
@immutable
class HomeSection {
  const HomeSection({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<MovieSummary> items;
  final bool isLoading;
  final String? error;

  /// 标记分区开始加载（保留旧数据，清除错误）。
  HomeSection startLoading() => HomeSection(items: items, isLoading: true);

  /// 标记分区加载失败（保留旧数据，记录错误信息）。
  HomeSection fail(Object error) =>
      HomeSection(items: items, error: error.toString());

  bool get isEmpty => items.isEmpty;
}

class HomeProvider extends ChangeNotifier {
  HomeProvider(this._service);

  final HomeService _service;

  HomeSection _recommends = const HomeSection();
  HomeSection _latest = const HomeSection();
  HomeSection _magnetUpdates = const HomeSection();
  bool _isLatestRefreshing = false;
  bool _isMagnetRefreshing = false;
  int _latestPage = 1;
  int _magnetPage = 1;

  HomeSection get recommends => _recommends;
  HomeSection get latest => _latest;
  HomeSection get magnetUpdates => _magnetUpdates;
  bool get isLatestRefreshing => _isLatestRefreshing;
  bool get isMagnetRefreshing => _isMagnetRefreshing;
  int get latestPage => _latestPage;
  int get magnetPage => _magnetPage;

  /// 并发加载三个分区，各自独立成功或失败。
  Future<void> loadAll() async {
    await Future.wait([
      loadSection(HomeSectionKind.recommends),
      loadSection(HomeSectionKind.latest),
      loadSection(HomeSectionKind.magnets),
    ]);
  }

  /// 仅重试指定分区的第 1 页请求；加载中则忽略。
  Future<void> retrySection(HomeSectionKind kind) async {
    if (_sectionOf(kind).isLoading) return;
    await loadSection(kind);
  }

  Future<void> loadSection(HomeSectionKind kind) async {
    _setSection(kind, _sectionOf(kind).startLoading());
    try {
      final items = switch (kind) {
        HomeSectionKind.recommends => await _service.getRecommends(),
        HomeSectionKind.latest => await _service.getLatest(page: 1),
        HomeSectionKind.magnets => await _service.getMagnetUpdates(page: 1),
      };
      if (kind == HomeSectionKind.latest) _latestPage = 1;
      if (kind == HomeSectionKind.magnets) _magnetPage = 1;
      _setSection(kind, HomeSection(items: items));
    } catch (e) {
      _setSection(kind, _sectionOf(kind).fail(e));
    }
  }

  HomeSection _sectionOf(HomeSectionKind kind) => switch (kind) {
    HomeSectionKind.recommends => _recommends,
    HomeSectionKind.latest => _latest,
    HomeSectionKind.magnets => _magnetUpdates,
  };

  void _setSection(HomeSectionKind kind, HomeSection section) {
    switch (kind) {
      case HomeSectionKind.recommends:
        _recommends = section;
      case HomeSectionKind.latest:
        _latest = section;
      case HomeSectionKind.magnets:
        _magnetUpdates = section;
    }
    notifyListeners();
  }

  Future<void> reshuffleLatest() async {
    if (_isLatestRefreshing) return;
    _isLatestRefreshing = true;
    notifyListeners();
    final nextPage = _latestPage + 1;
    try {
      final movies = await _service.getLatest(page: nextPage);
      _latest = HomeSection(items: movies);
      _latestPage = nextPage;
    } finally {
      _isLatestRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> reshuffleMagnets() async {
    if (_isMagnetRefreshing) return;
    _isMagnetRefreshing = true;
    notifyListeners();
    final nextPage = _magnetPage + 1;
    try {
      final movies = await _service.getMagnetUpdates(page: nextPage);
      _magnetUpdates = HomeSection(items: movies);
      _magnetPage = nextPage;
    } finally {
      _isMagnetRefreshing = false;
      notifyListeners();
    }
  }
}
