// lib/features/articles/widgets/article_widget_factory.dart
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:fwfh_cached_network_image/fwfh_cached_network_image.dart';
import 'package:jade/core/widgets/cached_image.dart';

/// 将资讯正文中的网络图片改用 [CachedImage] 渲染，
/// 使其自动跟随全局"模糊图片"设置，并复用解密缓存。
/// 网络 svg、`data:`、`asset:` 图片交给默认实现。
class ArticleWidgetFactory extends WidgetFactory
    with CachedNetworkImageFactory {
  @override
  Widget? buildImageWidget(BuildTree tree, ImageSource src) {
    final url = src.url;
    final uri = Uri.tryParse(url);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final isSvg = uri != null && uri.path.toLowerCase().endsWith('.svg');
    if (isNetwork && !isSvg) {
      return CachedImage(url, fit: BoxFit.fill);
    }
    return super.buildImageWidget(tree, src);
  }
}
