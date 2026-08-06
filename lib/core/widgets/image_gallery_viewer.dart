// lib/core/widgets/image_gallery_viewer.dart
import 'package:flutter/material.dart';
import 'package:jade/core/widgets/cached_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// 全屏大图预览：黑底、缩放（contained~4x）、左右切换、计数标题、关闭按钮。
class ImageGalleryViewer extends StatefulWidget {
  const ImageGalleryViewer({
    super.key,
    required this.urls,
    required this.initialIndex,
    this.itemBuilder,
  });

  final List<String> urls;
  final int initialIndex;
  final Widget Function(BuildContext context, String url, int index)?
      itemBuilder;

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  late final PageController _controller;
  late final List<PhotoViewController> _photoViewControllers;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _photoViewControllers = List.generate(
      widget.urls.length,
      (_) => PhotoViewController(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final controller in _photoViewControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      key: const Key('image-gallery-viewer'),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
          title: Text('${_currentIndex + 1} / ${widget.urls.length}'),
          centerTitle: true,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final childSize = Size(
              constraints.maxWidth * 2,
              constraints.maxHeight * 2,
            );
            return PhotoViewGallery.builder(
              key: const Key('image-gallery-pages'),
              pageController: _controller,
              itemCount: widget.urls.length,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              customSize: constraints.biggest,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              builder: (_, index) => PhotoViewGalleryPageOptions.customChild(
                childSize: childSize,
                controller: _photoViewControllers[index],
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained * 4,
                child: SizedBox.expand(
                  child:
                      widget.itemBuilder?.call(context, widget.urls[index], index) ??
                          CachedImage(
                            widget.urls[index],
                            key: Key('image-gallery-page-$index'),
                            fit: BoxFit.contain,
                          ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
