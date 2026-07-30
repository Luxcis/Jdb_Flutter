import 'package:flutter/material.dart';
import 'package:jade/features/actors/models/actor_filter.dart';

class ActorFilterSheet extends StatefulWidget {
  const ActorFilterSheet({super.key, required this.initialValue});

  final ActorFilter initialValue;

  @override
  State<ActorFilterSheet> createState() => _ActorFilterSheetState();
}

class _ActorFilterSheetState extends State<ActorFilterSheet> {
  late ActorFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) => Material(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                children: [
                  Text('筛选', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _draft = const ActorFilter();
                    }),
                    child: const Text('重置'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                itemCount: 6,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildRangeRow(index),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: const Text('应用筛选'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeRow(int index) => switch (index) {
    0 => _ActorRangeRow(
      label: '年龄',
      range: _draft.age,
      bounds: ActorFilter.defaultAge,
      onChanged: (range) => setState(() {
        _draft = _draft.copyWith(age: range);
      }),
    ),
    1 => _ActorRangeRow(
      label: '身高',
      range: _draft.height,
      bounds: ActorFilter.defaultHeight,
      onChanged: (range) => setState(() {
        _draft = _draft.copyWith(height: range);
      }),
    ),
    2 => _ActorRangeRow(
      label: '罩杯',
      range: _draft.cup,
      bounds: ActorFilter.defaultCup,
      valueLabel: cupLabel,
      onChanged: (range) => setState(() {
        _draft = _draft.copyWith(cup: range);
      }),
    ),
    3 => _ActorRangeRow(
      label: '胸围',
      range: _draft.bust,
      bounds: ActorFilter.defaultBust,
      onChanged: (range) => setState(() {
        _draft = _draft.copyWith(bust: range);
      }),
    ),
    4 => _ActorRangeRow(
      label: '腰围',
      range: _draft.waist,
      bounds: ActorFilter.defaultWaist,
      onChanged: (range) => setState(() {
        _draft = _draft.copyWith(waist: range);
      }),
    ),
    5 => _ActorRangeRow(
      label: '臀围',
      range: _draft.hips,
      bounds: ActorFilter.defaultHips,
      onChanged: (range) => setState(() {
        _draft = _draft.copyWith(hips: range);
      }),
    ),
    _ => throw ArgumentError.value(index, 'index', '未定义的演员范围筛选'),
  };
}

class _ActorRangeRow extends StatelessWidget {
  const _ActorRangeRow({
    required this.label,
    required this.range,
    required this.bounds,
    required this.onChanged,
    this.valueLabel = _numericRangeLabel,
  });

  final String label;
  final ActorRange range;
  final ActorRange bounds;
  final ValueChanged<ActorRange> onChanged;
  final String Function(ActorRange) valueLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label筛选',
    child: Row(
      children: [
        SizedBox(width: 36, child: Text(label)),
        Expanded(
          child: RangeSlider(
            values: RangeValues(range.min.toDouble(), range.max.toDouble()),
            min: bounds.min.toDouble(),
            max: bounds.max.toDouble(),
            divisions: bounds.max - bounds.min,
            onChanged: (values) =>
                onChanged(ActorRange(values.start.round(), values.end.round())),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            valueLabel(range),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    ),
  );
}

String cupLabel(ActorRange range) =>
    '${String.fromCharCode(65 + range.min)}–${String.fromCharCode(65 + range.max)}';

String _numericRangeLabel(ActorRange range) => '${range.min}–${range.max}';
