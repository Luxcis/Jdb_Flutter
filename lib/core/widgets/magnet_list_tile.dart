import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jade/core/models/magnet.dart';

/// Displays a magnet entry and copies its complete URI when tapped.
class MagnetListTile extends StatelessWidget {
  const MagnetListTile({super.key, required this.magnet});

  final Magnet magnet;

  String get _magnetUri {
    final hash = magnet.hash.trim();
    return hash.startsWith('magnet:?') ? hash : 'magnet:?xt=urn:btih:$hash';
  }

  Future<void> _copyMagnet(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _magnetUri));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('磁力链接已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = [
      '${magnet.filesCount} 个文件',
      if (magnet.size != null && magnet.size!.isNotEmpty) magnet.size!,
    ].join(' / ');
    return Semantics(
      button: true,
      label: '复制磁力链接 ${magnet.title ?? magnet.hash}',
      child: InkWell(
        onTap: () => _copyMagnet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                spacing: 10,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.file_download_outlined,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(
                      magnet.title ?? magnet.hash,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (magnet.isHighDefinition)
                    const _MagnetInfoBadge(label: '高清'),
                  if (magnet.hasSubtitle)
                    const _MagnetInfoBadge(
                      label: '字幕',
                      colorRole: _BadgeColorRole.pink,
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (magnet.publishDate != null)
                    Text(
                      magnet.publishDate!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the divider shared by magnet lists.
class MagnetListDivider extends StatelessWidget {
  const MagnetListDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

enum _BadgeColorRole { blue, pink }

class _MagnetInfoBadge extends StatelessWidget {
  const _MagnetInfoBadge({
    required this.label,
    this.colorRole = _BadgeColorRole.blue,
  });

  final String label;
  final _BadgeColorRole colorRole;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (colorRole) {
      _BadgeColorRole.blue => (
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      _BadgeColorRole.pink => (Colors.pink.shade600, Colors.pink.shade50),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
