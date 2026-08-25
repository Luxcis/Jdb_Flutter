import 'package:flutter/material.dart';
import 'package:jade/features/rankings/models/top250_filter.dart';

/// Top250 筛选底部弹窗：类型/年份 + 起始排名 + 是否忽略已看过。
class Top250FilterSheet extends StatefulWidget {
  const Top250FilterSheet({super.key, required this.value, required this.onChanged});

  final Top250Filter value;
  final ValueChanged<Top250Filter> onChanged;

  @override
  State<Top250FilterSheet> createState() => _Top250FilterSheetState();
}

class _Top250FilterSheetState extends State<Top250FilterSheet> {
  static const _videoTypes = [
    (label: '有码', value: '0'),
    (label: '无码', value: '1'),
    (label: '欧美', value: '2'),
    (label: 'FC2', value: '3'),
  ];
  static const _startRanks = [1, 51, 101, 151, 201];

  late Top250Filter _value = widget.value;

  void _emit(Top250Filter value) {
    setState(() => _value = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var year = DateTime.now().year; year >= 2008; year--) year,
    ];
    return ListView(
      key: const Key('top250-filter-list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('筛选', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CompactChoiceChip(
              label: '全部',
              selected: _value.type == 'all',
              onSelected: () =>
                  _emit(_value.copyWith(type: 'all', typeValue: '')),
            ),
            for (final type in _videoTypes)
              CompactChoiceChip(
                label: type.label,
                selected:
                    _value.type == 'video_type' &&
                    _value.typeValue == type.value,
                onSelected: () => _emit(
                  _value.copyWith(type: 'video_type', typeValue: type.value),
                ),
              ),
            for (final year in years)
              CompactChoiceChip(
                label: '$year',
                selected: _value.type == 'year' && _value.typeValue == '$year',
                onSelected: () =>
                    _emit(_value.copyWith(type: 'year', typeValue: '$year')),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('起始排名', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final startRank in _startRanks)
              CompactChoiceChip(
                label: '$startRank',
                selected: _value.startRank == startRank,
                onSelected: () => _emit(_value.copyWith(startRank: startRank)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('未标「看过」'),
          subtitle: const Text('仅查看还未被标记「看过」的影片'),
          value: _value.ignoreWatched,
          onChanged: (value) => _emit(_value.copyWith(ignoreWatched: value)),
        ),
      ],
    );
  }
}

class CompactChoiceChip extends StatelessWidget {
  const CompactChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
