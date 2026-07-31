import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';
import 'package:jade/features/actors/services/actor_movie_controller.dart';

/// 演员详情页的影片筛选底部面板。
///
/// 展示基本筛选（filter_tags）和标签筛选（tags），
/// 标签显示影片数量（如 `巨乳(64)`）。
/// 多选、即时生效。
class ActorMovieFilterSheet extends StatelessWidget {
  const ActorMovieFilterSheet({super.key, required this.controller});

  final ActorMovieController controller;

  static const _sortOptions = [
    ('发布日期', 'release'),
    ('更新时间', 'update'),
    ('评分', 'score'),
    ('热度', 'hit'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Text(
                  '筛选',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  initialValue: controller.sortBy,
                  onSelected: controller.changeSort,
                  itemBuilder: (_) => [
                    for (final (label, value) in _sortOptions)
                      PopupMenuItem(value: value, child: Text(label)),
                  ],
                  child: Text(
                    _sortOptions
                        .firstWhere(
                          (o) => o.$2 == controller.sortBy,
                          orElse: () => _sortOptions.first,
                        )
                        .$1,
                  ),
                ),
                if (controller.sortBy == 'release')
                  IconButton(
                    tooltip:
                        controller.orderBy == 'desc' ? '降序' : '升序',
                    onPressed: controller.toggleOrder,
                    icon: Icon(
                      controller.orderBy == 'desc'
                          ? Icons.south
                          : Icons.north,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (controller.filterTags.isNotEmpty) ...[
                  _TagGroup(
                    label: '基本',
                    tags: controller.filterTags,
                    selectedIds: controller.selectedTagIds,
                    showCount: false,
                    onToggle: controller.toggleTag,
                  ),
                  const SizedBox(height: 12),
                ],
                if (controller.tags.isNotEmpty)
                  _TagGroup(
                    label: '标签',
                    tags: controller.tags,
                    selectedIds: controller.selectedTagIds,
                    showCount: true,
                    onToggle: controller.toggleTag,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({
    required this.label,
    required this.tags,
    required this.selectedIds,
    required this.showCount,
    required this.onToggle,
  });

  final String label;
  final List<ActorTagItem> tags;
  final Set<String> selectedIds;
  final bool showCount;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(label),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(
                    showCount
                        ? '${tag.name}(${tag.videosCount})'
                        : tag.name,
                  ),
                  selected: selectedIds.contains(tag.id),
                  onSelected: (_) => onToggle(tag.id),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 6),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
