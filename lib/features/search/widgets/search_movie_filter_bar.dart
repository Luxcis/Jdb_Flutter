import 'package:flutter/material.dart';
import 'package:jade/features/search/models/search_movie_filter.dart';

class SearchMovieFilterBar extends StatelessWidget {
  const SearchMovieFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final SearchMovieFilter value;
  final ValueChanged<SearchMovieFilter> onChanged;

  void _notifyIfChanged(SearchMovieFilter next) {
    if (next.type == value.type &&
        next.availability == value.availability &&
        next.sort == value.sort) {
      return;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterRow<SearchMovieType>(
          title: '类型',
          options: SearchMovieType.values,
          selected: value.type,
          labelOf: (option) => option.label,
          onSelected: (type) => _notifyIfChanged(value.copyWith(type: type)),
        ),
        _FilterRow<SearchMovieAvailability>(
          title: '筛选',
          options: SearchMovieAvailability.values,
          selected: value.availability,
          labelOf: (option) => option.label,
          onSelected: (availability) =>
              _notifyIfChanged(value.copyWith(availability: availability)),
        ),
        _FilterRow<SearchMovieSort>(
          title: '排序',
          options: SearchMovieSort.values,
          selected: value.sort,
          labelOf: (option) => option.label,
          onSelected: (sort) => _notifyIfChanged(value.copyWith(sort: sort)),
        ),
      ],
    );
  }
}

class _FilterRow<T> extends StatelessWidget {
  const _FilterRow({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final String title;
  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(title, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 6,
                children: [
                  for (final option in options)
                    ChoiceChip(
                      label: Text(labelOf(option)),
                      selected: option == selected,
                      onSelected: (_) => onSelected(option),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
