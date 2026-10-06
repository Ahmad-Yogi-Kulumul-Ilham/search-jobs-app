import 'package:flutter/material.dart';

import '../app_services.dart';
import 'common.dart';
import 'jobs/jobs_page.dart';
import 'settings/settings_page.dart';
import 'sources/sources_page.dart';
import 'tracker/tracker_page.dart';

/// The app frame: a navigation rail and the page it selects.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.services});

  final AppServices services;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _refreshOnStart();
  }

  Future<void> _refreshOnStart() async {
    final result = await widget.services.refresh(manual: false);
    if (!mounted) return;
    final message = refreshMessage(result, manual: false);
    if (message != null) showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.work_outline),
                selectedIcon: Icon(Icons.work),
                label: Text('Lowongan'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: Text('Lamaran'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.rss_feed),
                label: Text('Sumber'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Pengaturan'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            // IndexedStack keeps each page's state (search text, scroll
            // position) while another page is showing.
            child: IndexedStack(
              index: _index,
              children: [
                JobsPage(services: services),
                TrackerPage(services: services),
                SourcesPage(services: services),
                SettingsPage(services: services),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
