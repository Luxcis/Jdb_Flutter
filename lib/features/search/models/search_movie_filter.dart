enum SearchMovieType {
  all('全部', 'all'),
  censored('有码', '0'),
  uncensored('无码', '1'),
  western('欧美', '2'),
  fc2('FC2', '3'),
  carton('动漫', '4');

  const SearchMovieType(this.label, this.value);

  final String label;
  final String value;
}

enum SearchMovieAvailability {
  all('全部', 'all'),
  canPlay('可播放', 'can_play'),
  magnets('含磁链', 'magnets'),
  subtitle('字幕', 'subtitle'),
  single('单体', 'single');

  const SearchMovieAvailability(this.label, this.value);

  final String label;
  final String value;
}

enum SearchMovieSort {
  relevance('相关度', 'relevance'),
  release('发布时间', 'release'),
  update('更新时间', 'update'),
  score('评分', 'score');

  const SearchMovieSort(this.label, this.value);

  final String label;
  final String value;
}

class SearchMovieFilter {
  const SearchMovieFilter({
    this.type = SearchMovieType.all,
    this.availability = SearchMovieAvailability.all,
    this.sort = SearchMovieSort.relevance,
  });

  final SearchMovieType type;
  final SearchMovieAvailability availability;
  final SearchMovieSort sort;

  SearchMovieFilter copyWith({
    SearchMovieType? type,
    SearchMovieAvailability? availability,
    SearchMovieSort? sort,
  }) => SearchMovieFilter(
    type: type ?? this.type,
    availability: availability ?? this.availability,
    sort: sort ?? this.sort,
  );
}
