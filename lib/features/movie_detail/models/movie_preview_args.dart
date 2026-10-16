class MoviePreviewArgs {
  const MoviePreviewArgs({
    required this.movieId,
    required this.title,
    this.videoUrl = '',
    this.onlineNumber,
  }) : assert(
         onlineNumber != null || videoUrl != '',
         '预告片需要 videoUrl，在线正片需要 onlineNumber。',
       );

  final String movieId;
  final String title;
  final String videoUrl;

  /// 在线正片来源的影片番号；非空表示本播放页为「正片」在线播放。
  final String? onlineNumber;

  /// 本播放页是否为在线正片来源。
  bool get isOnline => (onlineNumber ?? '').trim().isNotEmpty;

  /// 将 [videoUrl] 的 host 替换为当前选中线路 [lineBaseUrl] 的 host。
  ///
  /// 仅替换 scheme://authority（scheme、host、显式端口），保留原路径、
  /// 查询参数（签名）与 fragment；任一侧不是带 host 的 HTTP(S) 地址时
  /// 原样返回 [videoUrl]。
  static String replaceHostWithLine(String videoUrl, String? lineBaseUrl) {
    final uri = Uri.tryParse(videoUrl);
    final line = Uri.tryParse(lineBaseUrl ?? '');
    if (uri == null || !_isHttpHostUri(uri)) return videoUrl;
    if (line == null || !_isHttpHostUri(line)) return videoUrl;
    final authority = line.hasPort ? '${line.host}:${line.port}' : line.host;
    final original = uri.toString();
    final rest = original.substring(original.indexOf('://') + 3);
    final suffixStart = rest.indexOf(RegExp(r'[/?#]'));
    final suffix = suffixStart == -1 ? '' : rest.substring(suffixStart);
    return '${line.scheme}://$authority$suffix';
  }

  static bool _isHttpHostUri(Uri uri) =>
      (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;

  Uri? get videoUri {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}
