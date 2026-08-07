/// 热门短评周期，对应 /api/v1/reviews/hotly 的 period 参数。
enum ReviewPeriod {
  latest('latest'),
  weekly('weekly'),
  monthly('monthly'),
  quarterly('quarterly'),
  yearly('yearly'),
  all('all');

  const ReviewPeriod(this.value);

  final String value;
}
