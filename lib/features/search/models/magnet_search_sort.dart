enum MagnetSearchSort {
  relevance('相关度', 'relevance'),
  created('时间', 'created'),
  files('文件数', 'files'),
  size('文件大小', 'size');

  const MagnetSearchSort(this.label, this.apiValue);

  final String label;
  final String apiValue;
}
