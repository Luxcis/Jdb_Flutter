import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('再按一次退出应用')),
        );
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (i) => widget.navigationShell.goBranch(
            i,
            initialLocation: i == widget.navigationShell.currentIndex,
          ),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: '首页'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: '排行榜'),
            NavigationDestination(icon: Icon(Icons.category), label: '类别'),
            NavigationDestination(icon: Icon(Icons.people), label: '演员'),
            NavigationDestination(icon: Icon(Icons.person), label: '我的'),
          ],
        ),
      ),
    );
  }
}
