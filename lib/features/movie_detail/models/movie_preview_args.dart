class MoviePreviewArgs {
  const MoviePreviewArgs({
    required this.movieId,
    required this.title,
    required this.videoUrl,
  });

  final String movieId;
  final String title;
  final String videoUrl;

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
