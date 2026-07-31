import 'package:flutter/foundation.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/core/models/movie.dart';
import 'package:jade/core/models/paged_result.dart';
import 'package:jade/core/widgets/pagination_controller.dart';
import 'package:jade/features/actors/services/actor_service.dart';

/// 演员详情页的影片筛选状态管理。
///
/// 管理 [PaginationController]、标签选中状态、排序参数。
/// 标签或排序变化时通过 [movies.reloadWith] 即时刷新影片列表。
class ActorMovieController extends ChangeNotifier {
  ActorMovieController({
    required this.actorId,
    required this.type,
    required List<ActorTagItem> filterTags,
    required List<ActorTagItem> tags,
    required ActorService service,
  }) : _filterTags = filterTags,
       _tags = tags,
       _service = service,
       movies = PaginationController<MovieSummary>(
         fetch: (_) => throw StateError('controller not initialized'),
       ) {
    movies.addListener(_notifyFromMovies);
  }

  /// 演员 ID。
  final String actorId;

  /// 演员类别（0=有码, 1=无码, 2=欧美）。
  final int type;

  final ActorService _service;

  /// 影片分页控制器。
  final PaginationController<MovieSummary> movies;

  final List<ActorTagItem> _filterTags;

  /// 基本筛选标签列表（来源于演员详情的 filter_tags）。
  List<ActorTagItem> get filterTags => _filterTags;

  final List<ActorTagItem> _tags;

  /// 标签筛选列表（来源于演员详情的 tags）。
  List<ActorTagItem> get tags => _tags;

  final Set<String> _selectedTagIds = {};

  /// 当前选中的标签 ID 集合。
  Set<String> get selectedTagIds => Set.unmodifiable(_selectedTagIds);

  String _sortBy = 'release';

  /// 排序字段（release / update / score / hit）。
  String get sortBy => _sortBy;

  String _orderBy = 'desc';

  /// 排序方向（asc / desc），仅 sortBy == release 时生效。
  String get orderBy => _orderBy;

  bool _initialized = false;
  bool _disposed = false;

  /// 初始化控制器，触发首次影片加载。
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await movies.reloadWith(_fetchPage);
  }

  /// 切换标签选中状态，立即刷新影片列表。
  Future<void> toggleTag(String id) async {
    if (_disposed) return;
    if (_selectedTagIds.contains(id)) {
      _selectedTagIds.remove(id);
    } else {
      _selectedTagIds.add(id);
    }
    _notify();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  /// 修改排序字段，立即刷新影片列表。
  Future<void> changeSort(String sortBy) async {
    if (_disposed) return;
    _sortBy = sortBy;
    _notify();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  /// 切换升降序，立即刷新影片列表。
  Future<void> toggleOrder() async {
    if (_disposed) return;
    _orderBy = _orderBy == 'desc' ? 'asc' : 'desc';
    _notify();
    await movies.reloadWith(_fetchPage, preserveItems: true);
  }

  Future<PagedResult<MovieSummary>> _fetchPage(int page) =>
      _service.getActorMovies(
        actorId,
        type: type,
        filterByTags:
            _selectedTagIds.isEmpty ? null : _selectedTagIds.join(','),
        page: page,
        sortBy: _sortBy,
        orderBy: _orderBy,
      );

  void _notifyFromMovies() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    movies.removeListener(_notifyFromMovies);
    movies.dispose();
    super.dispose();
  }
}
