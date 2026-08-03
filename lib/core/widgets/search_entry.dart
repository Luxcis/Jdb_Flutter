import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jade/core/router/routes.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Semantics(
        button: true,
        label: '搜索',
        child: Material(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(AppRoutes.search),
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  spacing: 12,
                  children: [
                    Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                    Expanded(
                      child: Text(
                        '输入演员或番号等关键字',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SearchIconButton extends StatelessWidget {
  const SearchIconButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '搜索',
    onPressed: () => context.push(AppRoutes.search),
    icon: const Icon(Icons.search),
  );
}
