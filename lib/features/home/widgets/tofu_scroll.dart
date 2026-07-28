import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TofuItem {
  const TofuItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.color,
  });

  final String label;
  final IconData icon;
  final String route;
  final Color color;
}

class TofuScroll extends StatelessWidget {
  const TofuScroll({super.key});

  static const items = [
    TofuItem(
      label: '看热播',
      icon: Icons.play_circle,
      route: '/rankings',
      color: Colors.lightBlue,
    ),
    TofuItem(
      label: 'AV资讯',
      icon: Icons.article,
      route: '/articles',
      color: Colors.pinkAccent,
    ),
    TofuItem(
      label: '看短评',
      icon: Icons.reviews,
      route: '/reviews',
      color: Colors.orangeAccent,
    ),
    TofuItem(
      label: '找磁链',
      icon: Icons.link,
      route: '/search/magnet',
      color: Colors.green,
    ),
    TofuItem(
      label: '识演员',
      icon: Icons.person_search,
      route: '/search/image',
      color: Colors.purpleAccent,
    ),
    TofuItem(
      label: '识影片',
      icon: Icons.movie,
      route: '/search/image',
      color: Colors.indigoAccent,
    ),
    TofuItem(
      label: '系列',
      icon: Icons.collections,
      route: '/series',
      color: Colors.teal,
    ),
    TofuItem(
      label: '片商',
      icon: Icons.business,
      route: '/makers',
      color: Colors.deepOrangeAccent,
    ),
    TofuItem(
      label: '导演',
      icon: Icons.person,
      route: '/directors',
      color: Colors.blueGrey,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = items[i];
          return SizedBox(
            width: 84,
            child: Card(
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.16),
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(item.route),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    Icon(item.icon, size: 30, color: item.color),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
