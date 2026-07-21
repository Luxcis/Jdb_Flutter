import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TofuItem {
  const TofuItem({required this.label, required this.icon, required this.route});
  final String label;
  final IconData icon;
  final String route;
}

class TofuScroll extends StatelessWidget {
  const TofuScroll({super.key});

  static const items = [
    TofuItem(label: '看热播', icon: Icons.play_circle, route: '/rankings'),
    TofuItem(label: 'AV资讯', icon: Icons.article, route: '/articles'),
    TofuItem(label: '看短评', icon: Icons.reviews, route: '/reviews'),
    TofuItem(label: '找磁链', icon: Icons.link, route: '/search/magnet'),
    TofuItem(label: '识演员', icon: Icons.person_search, route: '/search/image'),
    TofuItem(label: '识影片', icon: Icons.movie, route: '/search/image'),
    TofuItem(label: '系列', icon: Icons.collections, route: '/series'),
    TofuItem(label: '片商', icon: Icons.business, route: '/makers'),
    TofuItem(label: '导演', icon: Icons.person, route: '/directors'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => context.push(items[i].route),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(items[i].icon, size: 28),
            const SizedBox(height: 4),
            Text(items[i].label, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
