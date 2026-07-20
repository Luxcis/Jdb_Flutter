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
  String? _error;

  List<MovieSummary> get recommends => _recommends;
  List<MovieSummary> get latest => _latest;
  List<MovieSummary> get magnetUpdates => _magnetUpdates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getRecommends(),
        _service.getLatest(),
        _service.getMagnetUpdates(),
      ]);
      _recommends = results[0];
      _latest = results[1];
      _magnetUpdates = results[2];
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reshuffleLatest() {
    _latest = List.from(_latest)..shuffle();
    notifyListeners();
  }

  void reshuffleMagnets() {
    _magnetUpdates = List.from(_magnetUpdates)..shuffle();
    notifyListeners();
  }
}
