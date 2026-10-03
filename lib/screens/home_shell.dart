import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'admin_pages.dart';
import 'history_page.dart';
import 'tab_view.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Mi consumo', 'Socios', 'Catálogo', 'Whitelist'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final myTab = TabView(uid: app.uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(app.isAdmin ? _titles[_index] : 'Sa i Fort · Mi consumo'),
        actions: [
          if (!app.isAdmin || _index == 0)
            IconButton(
              tooltip: 'Historial de pagos',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HistoryPage(uid: app.uid)),
              ),
            ),
          IconButton(tooltip: 'Cerrar sesión (${app.email})', icon: const Icon(Icons.logout), onPressed: app.signOut),
        ],
      ),
      body: app.isAdmin
          ? IndexedStack(index: _index, children: [myTab, const MembersPage(), const CatalogPage(), const WhitelistPage()])
          : myTab,
      bottomNavigationBar: app.isAdmin
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.sports_bar_outlined), label: 'Mi consumo'),
                NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Socios'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Catálogo'),
                NavigationDestination(icon: Icon(Icons.how_to_reg_outlined), label: 'Whitelist'),
              ],
            )
          : null,
    );
  }
}
