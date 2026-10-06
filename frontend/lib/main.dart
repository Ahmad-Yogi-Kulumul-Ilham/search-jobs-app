import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import 'ui/jobs_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final repository = JobRepository(
    database: JobDatabase.open(p.join(directory.path, 'jobs.db')),
    sources: allSources,
  );
  runApp(SearchJobsApp(repository: repository));
}

class SearchJobsApp extends StatelessWidget {
  const SearchJobsApp({super.key, required this.repository});

  final JobRepository repository;

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
      home: JobsPage(repository: repository),
    );
  }
}
