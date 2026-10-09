import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/root_tab_controller.dart';
import 'contacts_page.dart';
import 'settings_page.dart';
import 'upcoming_page.dart';

/// 底部导航外壳。
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  @override
  Widget build(BuildContext context) {
    final RootTabController tabs = context.watch<RootTabController>();
    return Scaffold(
      body: IndexedStack(
        index: tabs.index,
        children: const <Widget>[
          UpcomingPage(),
          ContactsPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabs.index,
        onDestinationSelected: tabs.goTo,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.cake_outlined),
            selectedIcon: Icon(Icons.cake_rounded),
            label: '即将到来',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: '联系人',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
