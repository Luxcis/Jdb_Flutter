import 'package:flutter/material.dart';

class SearchKeywordSection extends StatelessWidget {
  const SearchKeywordSection({
    super.key,
    required this.title,
    required this.keywords,
    required this.onSelected,
    this.trailing,
  });

  final String title;
  final List<String> keywords;
  final ValueChanged<String> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            children: [
              Text(title, style: titleStyle),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final keyword in keywords)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(keyword),
                  onPressed: () => onSelected(keyword),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
