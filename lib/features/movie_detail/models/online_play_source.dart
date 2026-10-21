/// 在线播放源：把影片番号映射为可由系统浏览器打开的站点链接。
///
/// 播放源的唯一事实来源是 [onlinePlaySources] 注册表；抽屉 UI 与链接
/// 构造只读注册表。新增模板式播放源时，在注册表中追加一条
/// [UrlTemplateOnlinePlaySource] 定义即可；需要特殊构造逻辑的源可实现
/// [OnlinePlaySource] 接口，UI 层零改动。
abstract interface class OnlinePlaySource {
  /// 稳定标识，用于测试与埋点定位。
  String get id;

  /// 抽屉条目展示名称。
  String get label;

  /// 域名说明，作为抽屉条目的副标题。
  String get host;

  /// 由影片番号构造目标站点链接。
  Uri buildUrl(String number);
}

/// URL 模板式播放源：模板中的 `{number}` 占位符由番号替换。
final class UrlTemplateOnlinePlaySource implements OnlinePlaySource {
  const UrlTemplateOnlinePlaySource({
    required this.id,
    required this.label,
    required this.host,
    required this.urlTemplate,
  });

  @override
  final String id;

  @override
  final String label;

  @override
  final String host;

  /// 以 `{number}` 为番号占位符的 URL 模板。
  final String urlTemplate;

  @override
  Uri buildUrl(String number) =>
      Uri.parse(urlTemplate.replaceFirst('{number}', normalizeMovieNumber(number)));

  @override
  String toString() => 'UrlTemplateOnlinePlaySource($id)';
}

/// 番号代入链接前的规整：去除两侧空白并转小写。
///
/// jable、missav 等站点的 URL slug 为全小写，数据库中的大写番号
/// （如 `IPX-538`）直接拼接会得到 404 链接。
String normalizeMovieNumber(String number) => number.trim().toLowerCase();

/// 影片番号是否可用于在线播放（trim 后非空）。
bool hasUsableMovieNumber(String number) => number.trim().isNotEmpty;

/// 内置播放源注册表，按抽屉显示顺序排列。
const List<OnlinePlaySource> onlinePlaySources = <OnlinePlaySource>[
  UrlTemplateOnlinePlaySource(
    id: 'jable',
    label: 'Jable',
    host: 'jable.tv',
    urlTemplate: 'https://jable.tv/videos/{number}',
  ),
  UrlTemplateOnlinePlaySource(
    id: 'supjav',
    label: 'SupJav',
    host: 'supjav.com',
    urlTemplate: 'https://supjav.com/{number}',
  ),
  UrlTemplateOnlinePlaySource(
    id: 'missav',
    label: 'MissAV',
    host: 'missav.live',
    urlTemplate: 'https://missav.live/{number}',
  ),
];
