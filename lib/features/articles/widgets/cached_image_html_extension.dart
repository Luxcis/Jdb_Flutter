// lib/features/articles/widgets/cached_image_html_extension.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:jade/core/widgets/cached_image.dart';

/// 将资讯正文中的网络图片改用 [CachedImage] 渲染，
/// 使其自动跟随全局"模糊图片"设置。
class CachedImageHtmlExtension extends HtmlExtension {
  const CachedImageHtmlExtension();

  @override
  Set<String> get supportedTags => {'img'};

  @override
  bool matches(ExtensionContext context) {
    if (context.currentStep != CurrentStep.building) return false;
    final element = context.styledElement;
    if (element is! ImageElement) return false;
    final uri = Uri.tryParse(element.src);
    final isNetwork = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    return isNetwork && !element.src.endsWith('.svg');
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final element = context.styledElement as ImageElement;
    final imageStyle = Style(
      width: element.width,
      height: element.height,
    ).merge(context.styledElement!.style);
    return WidgetSpan(
      alignment: context.style!.verticalAlign
          .toPlaceholderAlignment(context.style!.display),
      baseline: TextBaseline.alphabetic,
      child: CssBoxWidget(
        style: imageStyle,
        childIsReplaced: true,
        child: CachedImage(
          element.src,
          width: imageStyle.width?.value,
          height: imageStyle.height?.value,
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}
