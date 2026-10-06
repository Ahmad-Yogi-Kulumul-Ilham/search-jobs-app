import 'dart:async';

import 'package:flutter/material.dart';

import '../app_services.dart';
import 'common.dart';
import 'cv/cv_page.dart';
import 'jobs/jobs_page.dart';
import 'settings/settings_page.dart';
import 'sources/sources_page.dart';
import 'tracker/tracker_page.dart';

/// The app frame: a navigation rail and the page it selects.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.services});

  final AppServices services;

  /// How often the app looks for due refreshes and reminders while open.
  static const checkEvery = Duration(minutes: 30);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(AppShell.checkEvery, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// An automatic refresh only fetches sources whose data is old enough, so
  /// running it often is cheap.
  Future<void> _check() async {
    final result = await widget.services.refresh(manual: false);
    await widget.services.checkReminders();
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
          ListenableBuilder(
            listenable: services,
            builder: (context, _) {
              final due = services.reminders().length;
              return NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (index) =>
                    setState(() => _index = index),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.work_outline),
                    selectedIcon: Icon(Icons.work),
                    label: Text('Lowongan'),
                  ),
                  NavigationRailDestination(
                    icon: Badge(
                      isLabelVisible: due > 0,
                      label: Text('$due'),
                      child: const Icon(Icons.fact_check_outlined),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: due > 0,
                      label: Text('$due'),
                      child: const Icon(Icons.fact_check),
                    ),
                    label: const Text('Lamaran'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.badge_outlined),
                    selectedIcon: Icon(Icons.badge),
                    label: Text('CV'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.rss_feed),
                    label: Text('Sumber'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('Pengaturan'),
                  ),
                ],
              );
            },
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
                CvPage(services: services),
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
