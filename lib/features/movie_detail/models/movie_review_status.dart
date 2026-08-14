/// 影片详情影评操作使用的服务端状态。
enum MovieReviewStatus {
  wantWatch('want_watch'),
  watched('watched');

  const MovieReviewStatus(this.wireValue);

  /// 服务端请求体使用的状态值。
  final String wireValue;
}
