import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:jade/core/providers/theme_provider.dart';
import 'package:jade/core/router/app_router.dart';
import 'package:jade/core/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'Jade',
          theme: lightDynamic != null
              ? ThemeData(colorScheme: lightDynamic)
              : AppTheme.light(),
          darkTheme: darkDynamic != null
              ? ThemeData(colorScheme: darkDynamic)
              : AppTheme.dark(),
          themeMode: themeProvider.themeMode,
          routerConfig: AppRouter.build(),
        );
      },
    );
  }
}
