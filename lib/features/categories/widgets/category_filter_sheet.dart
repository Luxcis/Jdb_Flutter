import 'package:flutter/material.dart';
import 'package:jade/features/categories/models/category_filter.dart';
import 'package:jade/features/categories/services/category_tab_controller.dart';

class CategoryFilterSheet extends StatelessWidget {
  const CategoryFilterSheet({super.key, required this.controller});

  final CategoryTabController controller;

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
                Text('筛选', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                PopupMenuButton<CategorySort>(
                  key: const Key('category-sort-menu'),
                  initialValue: controller.filter.sort,
                  onSelected: controller.changeSort,
                  itemBuilder: (_) => [
                    for (final sort in CategorySort.values)
                      PopupMenuItem(value: sort, child: Text(sort.label)),
                  ],
                  child: Text(controller.filter.sort.label),
                ),
                if (controller.filter.sort == CategorySort.release)
                  IconButton(
                    key: const Key('category-order-toggle'),
                    tooltip: controller.filter.orderBy == 'desc' ? '降序' : '升序',
                    onPressed: controller.toggleOrder,
                    icon: Icon(
                      controller.filter.orderBy == 'desc'
                          ? Icons.south
                          : Icons.north,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _FilterBody(controller: controller)),
        ],
      ),
    );
  }
}

class _FilterBody extends StatelessWidget {
  const _FilterBody({required this.controller});

  final CategoryTabController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.tagsLoading && controller.groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.tagsError != null && controller.groups.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: controller.retryTags,
          icon: const Icon(Icons.refresh),
          label: const Text('筛选内容加载失败，点击重试'),
        ),
      );
    }
    return ListView.separated(
      key: const Key('category-filter-list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: controller.groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = controller.groups[index];
        final selected = controller.filter.selectedValues(group.categoryId);
        return Row(
          key: Key('category-filter-group-${group.categoryId}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(group.category),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in group.tags)
                    FilterChip(
                      key: Key(
                        'category-filter-${group.categoryId}-${item.id}',
                      ),
                      label: Text(item.name),
                      selected: selected.contains(item.id),
                      onSelected: (_) =>
                          controller.toggleFilter(group.categoryId, item.id),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
