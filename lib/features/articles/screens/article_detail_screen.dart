import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/utils/time_format.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/core/widgets/image_gallery_viewer.dart';
import 'package:jade/features/articles/models/article.dart';
import 'package:jade/features/articles/services/article_service.dart';
import 'package:jade/features/articles/widgets/article_widget_factory.dart';

/// 将正文中的图片地址统一改写为接口返回的 [imageDomain]：
///
/// - 绝对 http/https 与协议相对（`//host/...`）地址：替换其 origin，
///   保留路径与 query，即 `imageDomain + 原路径`；
/// - 相对路径（`/x`、`x`）：拼接 `imageDomain`；
/// - 已在 `imageDomain` 下的 src 保持不变（幂等，避免前缀重复）；
/// - `data:`、`asset:`、`file:` 等非网络 src 保持不变；
/// - `imageDomain` 为空时不处理。
String resolveArticleImageUrls(String content, String? imageDomain) {
  final domain = imageDomain?.trim();
  if (domain == null || domain.isEmpty) return content;
  final base = domain.startsWith('//') ? 'https:$domain' : domain;
  final pattern = RegExp(r'src="([^"]+)"');
  return content.replaceAllMapped(pattern, (m) {
    final src = m[1]!;
    if (src == base || src.startsWith('$base/')) return m[0]!;
    final uri = Uri.tryParse(src);
    if (uri == null) return m[0]!;
    if (src.startsWith('//') ||
        uri.scheme == 'http' ||
        uri.scheme == 'https') {
      final pathAndQuery =
          uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
      return 'src="$base$pathAndQuery"';
    }
    if (uri.scheme.isNotEmpty) return m[0]!;
    final url = src.startsWith('/') ? '$base$src' : '$base/$src';
    return 'src="$url"';
  });
}

/// 提取正文中所有网络且非 svg 的图片地址，供大图预览切换与定位。
List<String> extractImageUrls(String content) {
  final urls = <String>[];
  final pattern = RegExp(r'src="([^"]+)"');
  for (final match in pattern.allMatches(content)) {
    final src = match[1]!;
    final uri = Uri.tryParse(src);
    if (uri == null) continue;
    if (uri.scheme != 'http' && uri.scheme != 'https') continue;
    if (uri.path.toLowerCase().endsWith('.svg')) continue;
    urls.add(src);
  }
  return urls;
}

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({super.key, required this.id});
  final String id;
  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  ArticleDetail? _detail;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final api = ApiClient.instanceOrNull;
    if (api == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '网络未就绪';
        });
      }
      return;
    }
    try {
      final detail = await ArticleService(api).getArticleDetail(widget.id);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('资讯详情')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return ErrorRetryWidget(message: error.toString(), onRetry: _load);
    }
    final detail = _detail!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final content =
        resolveArticleImageUrls(detail.content ?? '', detail.imageDomain);
    final imageUrls = extractImageUrls(content);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.title,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (detail.author != null && detail.author!.isNotEmpty) ...[
                Expanded(
                  child: Text(
                    detail.author!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (detail.category != null && detail.category!.isNotEmpty) ...[
                Text(
                  detail.category!,
                  style: textTheme.labelMedium?.copyWith(color: Colors.red),
                ),
                const SizedBox(width: 12),
              ],
              if (formatIsoRelativeTime(detail.releasedAt).isNotEmpty)
                Text(
                  formatIsoRelativeTime(detail.releasedAt),
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          HtmlWidget(
            content,
            factoryBuilder: () => ArticleWidgetFactory(),
            textStyle: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: scheme.onSurface,
            ),
            onTapImage: (image) {
              final url = image.sources.first.url;
              final index = imageUrls.indexOf(url);
              final urls = index < 0 ? [url] : imageUrls;
              final initialIndex = index < 0 ? 0 : index;
              showDialog<void>(
                context: context,
                useSafeArea: false,
                builder: (_) =>
                    ImageGalleryViewer(urls: urls, initialIndex: initialIndex),
              );
            },
          ),
        ],
      ),
    );
  }
}
