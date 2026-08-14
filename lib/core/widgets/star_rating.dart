import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.score,
    this.semanticLabel = '评分',
    this.size = 18,
    this.onChanged,
    this.enabled = true,
  });

  final double score;
  final String semanticLabel;
  final double size;
  final ValueChanged<int>? onChanged;
  final bool enabled;

  double get _starScore {
    final normalized = score > 5 ? score / 2 : score;
    return normalized.clamp(0, 5).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final value = _starScore;
    final color = Theme.of(context).colorScheme.tertiary;
    if (onChanged != null) {
      return _buildInteractive(value, color);
    }
    return Semantics(
      label: '$semanticLabel ${_formatScore(score)} 分',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 1,
          children: [
            for (var index = 0; index < 5; index++)
              Icon(_iconFor(value - index), size: size, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractive(double value, Color color) {
    return Semantics(
      label: value == 0
          ? '$semanticLabel 未评分'
          : '$semanticLabel ${value.toInt()} 分',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 1,
        children: [
          for (var index = 0; index < 5; index++)
            Semantics(
              button: true,
              enabled: enabled,
              selected: value >= index + 1,
              label: '${index + 1}分',
              child: InkResponse(
                key: Key('star-rating-${index + 1}'),
                onTap: enabled ? () => onChanged!(index + 1) : null,
                radius: 24,
                child: SizedBox.square(
                  dimension: size < 48 ? 48 : size,
                  child: Icon(
                    value >= index + 1
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: size,
                    color: color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(double value) {
    if (value >= 1) return Icons.star_rounded;
    if (value > 0) return Icons.star_half_rounded;
    return Icons.star_border_rounded;
  }

  String _formatScore(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }
}
