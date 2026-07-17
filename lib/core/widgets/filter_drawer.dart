import 'package:flutter/material.dart';

class FilterSchema {
  const FilterSchema({required this.groups});
  final List<FilterGroup> groups;
}

class FilterGroup {
  const FilterGroup({required this.label, required this.items});
  final String label;
  final List<({String label, String value})> items;
}

class FilterDrawer extends StatefulWidget {
  const FilterDrawer({super.key, required this.schema, required this.onChanged, this.initialValues});
  final FilterSchema schema;
  final void Function(Map<String, String>) onChanged;
  final Map<String, String>? initialValues;

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
  late final Map<String, String> _values;

  @override
  void initState() {
    super.initState();
    _values = Map.from(widget.initialValues ?? {});
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(children: widget.schema.groups.map((g) =>
                ExpansionTile(title: Text(g.label), children: g.items.map((item) =>
                  RadioListTile<String>(
                    title: Text(item.label),
                    value: item.value,
                    groupValue: _values[g.label],
                    onChanged: (v) {
                      setState(() { if (v != null) _values[g.label] = v; });
                    },
                  ),
                ).toList()),
              ).toList()),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onChanged(Map.from(_values));
                    Navigator.pop(context);
                  },
                  child: const Text('确认'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
