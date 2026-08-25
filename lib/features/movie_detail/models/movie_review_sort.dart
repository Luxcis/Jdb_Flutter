/// 影片详情短评列表的排序方式。
enum MovieReviewSort {
  hotly('hotly'),
  recently('recently');

  const MovieReviewSort(this.value);

  /// 服务端排序参数使用的值。
  final String value;
}
