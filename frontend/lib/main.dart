import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import 'app_services.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final database = AppDatabase.open(p.join(directory.path, 'jobs.db'));
  runApp(
    SearchJobsApp(
      services: AppServices(
        database: database,
        repository: JobRepository(database: database),
      ),
    ),
  );
}

class SearchJobsApp extends StatelessWidget {
  const SearchJobsApp({super.key, required this.services});

  final AppServices services;

  static const _seedColor = Color(0xFF2F6FED);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pencari Kerja Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seedColor),
      darkTheme: ThemeData(
        colorSchemeSeed: _seedColor,
        brightness: Brightness.dark,
      ),
      home: AppShell(services: services),
    );
  }
}
