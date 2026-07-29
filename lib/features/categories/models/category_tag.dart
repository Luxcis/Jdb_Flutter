import 'package:jade/core/network/api_data.dart';

class CategoryTagGroup {
  const CategoryTagGroup({
    required this.category,
    required this.categoryId,
    required this.tags,
  });

  final String category;
  final String categoryId;
  final List<CategoryTagItem> tags;

  factory CategoryTagGroup.fromJson(Map<String, dynamic> json) =>
      CategoryTagGroup(
        category: apiString(json['category']) ?? '',
        categoryId: apiString(json['category_id']) ?? '',
        tags: apiList(
          json['tags'],
          const [],
        ).map(CategoryTagItem.fromJson).toList(growable: false),
      );
}

class CategoryTagItem {
  const CategoryTagItem({
    required this.id,
    required this.name,
    required this.videosCount,
  });

  final String id;
  final String name;
  final int videosCount;

  factory CategoryTagItem.fromJson(Map<String, dynamic> json) =>
      CategoryTagItem(
        id: apiString(json['id']) ?? '',
        name: apiString(json['name']) ?? '',
        videosCount: apiInt(json['videos_count'], 0),
      );
}
