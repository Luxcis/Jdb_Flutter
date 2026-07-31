import 'package:flutter/material.dart';
import 'package:jade/core/models/actor.dart';

/// 显示演员信息面板。
Future<void> showActorInfoSheet(
  BuildContext context, {
  required ActorDetail actor,
}) {
  final size = MediaQuery.sizeOf(context);
  final colors = Theme.of(context).colorScheme;

  return showModalBottomSheet<void>(
    context: context,
    constraints: BoxConstraints.tightFor(height: size.height / 3),
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: colors.surfaceContainer,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ActorInfoSheet(actor: actor),
  );
}

class _ActorInfoSheet extends StatelessWidget {
  const _ActorInfoSheet({required this.actor});

  final ActorDetail actor;

  String _textOrPlaceholder(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '--' : normalized;
  }

  String _numberOrPlaceholder(int? value, {String suffix = ''}) {
    if (value == null) return '--';
    return '$value$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, colors),
            const SizedBox(height: 18),
            _InfoRow(
              left: _InfoItem(
                label: '生日',
                value: _textOrPlaceholder(actor.birthday),
              ),
              right: _InfoItem(
                label: '年龄',
                value: _numberOrPlaceholder(actor.age, suffix: ' 岁'),
              ),
            ),
            const SizedBox(height: 12),
            _InfoItem(
              label: '出生地',
              value: _textOrPlaceholder(actor.birthplace),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              left: _InfoItem(
                label: '罩杯',
                value: _textOrPlaceholder(actor.cup),
              ),
              right: _InfoItem(
                label: '胸围',
                value: _textOrPlaceholder(actor.bust),
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              left: _InfoItem(
                label: '腰围',
                value: _textOrPlaceholder(actor.waist),
              ),
              right: _InfoItem(
                label: '臀围',
                value: _textOrPlaceholder(actor.hip),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            actor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${actor.movieCount} 部影片',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 20),
        Expanded(child: right),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
