import 'package:flutter/material.dart';
import 'package:jade/features/movie_detail/models/online_play_source.dart';

/// 影片详情「在线播放」源选择抽屉。
///
/// 按注册表顺序列出播放源；点选后关闭抽屉并传出该源构造的链接，
/// 打开浏览器与失败提示由调用方处理。
class OnlinePlaySourceSheet extends StatelessWidget {
  const OnlinePlaySourceSheet({super.key, required this.number});

  /// 当前影片番号；链接在点选时由源定义构造。
  final String number;

  /// 弹出抽屉；返回点选源的链接，用户取消时为 null。
  static Future<Uri?> show(
    BuildContext context, {
    required String number,
  }) => showModalBottomSheet<Uri>(
    context: context,
    showDragHandle: true,
    builder: (_) => OnlinePlaySourceSheet(number: number),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(
              '选择在线播放源',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final source in onlinePlaySources)
            ListTile(
              key: Key('online-play-source-${source.id}'),
              title: Text(source.label),
              subtitle: Text(source.host),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.of(context).pop(source.buildUrl(number)),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
