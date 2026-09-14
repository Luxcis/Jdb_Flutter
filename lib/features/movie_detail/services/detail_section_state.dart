import 'package:flutter/foundation.dart';
import 'package:jade/core/models/review.dart';
import 'package:jade/features/movie_detail/models/movie_review_sort.dart';

/// 详情页单个数据区块的加载状态：
/// 各区块独立通知，加载/出错/重试只重建自己的子树，不刷新整页。
class DetailSectionState<T> extends ChangeNotifier {
  DetailSectionState({this.initiallyLoading = true});

  /// 进入页面即发起加载的区块保持 true；按需加载的区块创建 false。
  final bool initiallyLoading;

  List<T> _items = const [];
  Object? _error;
  bool _loading = true;

  List<T> get items => _items;
  Object? get error => _error;
  bool get loading => _loading;

  bool _disposed = false;

  void beginLoad() {
    if (_disposed) return;
    _loading = true;
    _error = null;
    notifyListeners();
  }

  void loaded(List<T> items) {
    if (_disposed) return;
    _items = List.unmodifiable(items);
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void failed(Object error) {
    if (_disposed) return;
    _error = error;
    _loading = false;
    notifyListeners();
  }

  /// 短评类区块的「沿用空状态」策略：请求失败时展示空列表而非错误态。
  void failedAsEmpty() {
    if (_disposed) return;
    _items = const [];
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void reset({List<T> items = const []}) {
    if (_disposed) return;
    _items = List.unmodifiable(items);
    _error = null;
    _loading = initiallyLoading;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 基本信息卡上的「我的短评状态」：当前短评 + 突变加载中。
/// 独立通知，状态变化只驱动「基本信息」Tab 重建。
class ReviewStatusState extends ChangeNotifier {
  ReviewStatusState({this.review, this.mutationLoading = false});

  Review? review;
  bool mutationLoading = false;

  bool _disposed = false;

  void updateReview(Review? review) {
    if (_disposed) return;
    this.review = review;
    notifyListeners();
  }

  void setMutationLoading(bool loading) {
    if (_disposed) return;
    mutationLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 短评区块状态：列表 + 当前排序 + 加载中。
/// 失败沿用空状态（与既有交互一致），错误仅记入 error 供日志/调试。
class ReviewSectionState extends ChangeNotifier {
  ReviewSectionState({this.sort = MovieReviewSort.hotly});

  List<Review> _items = const [];
  MovieReviewSort sort;
  bool _loading = false;
  bool _disposed = false;

  List<Review> get items => _items;
  bool get loading => _loading;

  void beginLoad(MovieReviewSort newSort) {
    if (_disposed) return;
    sort = newSort;
    _loading = true;
    notifyListeners();
  }

  void loaded(List<Review> reviews) {
    if (_disposed) return;
    _items = List.unmodifiable(reviews);
    _loading = false;
    notifyListeners();
  }

  void failedAsEmpty() {
    if (_disposed) return;
    _items = const [];
    _loading = false;
    notifyListeners();
  }

  void reset() {
    if (_disposed) return;
    _items = const [];
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
