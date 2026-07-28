import 'package:flutter/foundation.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/features/home/services/home_service.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider(this._service);

  final HomeService _service;

  List<MovieSummary> _recommends = [];
  List<MovieSummary> _latest = [];
  List<MovieSummary> _magnetUpdates = [];
  bool _isLoading = false;
  bool _isLatestRefreshing = false;
  bool _isMagnetRefreshing = false;
  int _latestPage = 1;
  int _magnetPage = 1;
  String? _error;

  List<MovieSummary> get recommends => _recommends;
  List<MovieSummary> get latest => _latest;
  List<MovieSummary> get magnetUpdates => _magnetUpdates;
  bool get isLoading => _isLoading;
  bool get isLatestRefreshing => _isLatestRefreshing;
  bool get isMagnetRefreshing => _isMagnetRefreshing;
  int get latestPage => _latestPage;
  int get magnetPage => _magnetPage;
  String? get error => _error;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getRecommends(),
        _service.getLatest(page: 1),
        _service.getMagnetUpdates(page: 1),
      ]);
      _recommends = results[0];
      _latest = results[1];
      _magnetUpdates = results[2];
      _latestPage = 1;
      _magnetPage = 1;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reshuffleLatest() async {
    if (_isLatestRefreshing) return;
    _isLatestRefreshing = true;
    notifyListeners();
    final nextPage = _latestPage + 1;
    try {
      final movies = await _service.getLatest(page: nextPage);
      _latest = movies;
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
      _magnetUpdates = movies;
      _magnetPage = nextPage;
    } finally {
      _isMagnetRefreshing = false;
      notifyListeners();
    }
  }
}
