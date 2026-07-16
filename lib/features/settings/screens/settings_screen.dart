import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/features/settings/widgets/setting_item.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeDropdownItems = [
      const DropdownMenuItem(
        value: ThemeMode.light,
        child: Text('浅色'),
      ),
      const DropdownMenuItem(
        value: ThemeMode.dark,
        child: Text('深色'),
      ),
      const DropdownMenuItem(
        value: ThemeMode.system,
        child: Text('跟随系统'),
      ),
    ];
    final themeSettingsItem = SettingItem(
      title: '应用主题',
      icon: Icons.brightness_4,
      editor: DropdownButton(
        value: themeProvider.themeMode,
        items: themeDropdownItems,
        onChanged: (ThemeMode? newTheme) {
          if (newTheme == null) return;
          themeProvider.setThemeMode(newTheme);
        },
      ),
      onTap: null,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          themeSettingsItem,
        ],
      ),
    );
  }
}
