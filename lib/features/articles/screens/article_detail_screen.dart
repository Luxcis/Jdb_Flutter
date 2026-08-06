import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:jade/core/network/api_client.dart';
import 'package:jade/core/utils/time_format.dart';
import 'package:jade/core/widgets/error_retry_widget.dart';
import 'package:jade/features/articles/models/article.dart';
import 'package:jade/features/articles/services/article_service.dart';
import 'package:jade/features/articles/widgets/cached_image_html_extension.dart';

/// 将正文中相对路径的图片地址拼接为完整 URL。
///
/// 跳过已有 scheme（如 https:、data:）的 src；`imageDomain` 为空时不处理。
String resolveArticleImageUrls(String content, String? imageDomain) {
  final domain = imageDomain?.trim();
  if (domain == null || domain.isEmpty) return content;
  final base = domain.startsWith('//') ? 'https:$domain' : domain;
  final pattern = RegExp(r'src="(?![a-zA-Z]+:)([^"]+)"');
  return content.replaceAllMapped(pattern, (m) {
    final src = m[1]!;
    if (src.startsWith('//')) return 'src="https:$src"';
    final url = src.startsWith('/') ? '$base$src' : '$base/$src';
    return 'src="$url"';
  });
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
          Html(
            data: resolveArticleImageUrls(
              detail.content ?? '',
              detail.imageDomain,
            ),
            extensions: const [CachedImageHtmlExtension()],
            style: {
              'body': Style(
                fontSize: FontSize(15),
                lineHeight: LineHeight(1.6),
                color: scheme.onSurface,
              ),
            },
          ),
        ],
      ),
    );
  }
}
