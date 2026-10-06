import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:search_jobs_app/app_services.dart';
import 'package:search_jobs_app/main.dart';
import 'package:search_jobs_app/notifier.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

const ratesBody =
    '{"amount": 1.0, "base": "USD", "date": "2026-10-05", '
    '"rates": {"IDR": 18000, "EUR": 0.9}}';

/// Builds the app's services over an in-memory database holding [jobs].
///
/// Every built-in source counts as freshly fetched, so startup only asks for
/// exchange rates. Other requests are answered by [onRequest], and fail the
/// test when it is not given.
AppServices testServices(
  WidgetTester tester, {
  List<Job> jobs = const [],
  http.Response? Function(http.Request request)? onRequest,
  Notifier? notifier,
}) {
  final database = AppDatabase.inMemory();
  addTearDown(database.close);
  final now = DateTime.now();
  for (final source in builtInSources) {
    database.jobs.saveFetch(source.id, const [], now);
  }
  database.jobs.saveFetch('remoteok', jobs, now);
  return AppServices(
    database: database,
    notifier: notifier,
    repository: JobRepository(
      database: database,
      client: MockClient((request) async {
        if (request.url.host == 'api.frankfurter.dev') {
          return http.Response(ratesBody, 200);
        }
        return onRequest?.call(request) ??
            fail('unexpected request to ${request.url}');
      }),
    ),
  );
}

/// Shows the whole app at a desktop window size.
Future<void> pumpApp(WidgetTester tester, AppServices services) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SearchJobsApp(services: services));
  await tester.pumpAndSettle();
}

/// Switches to the page named [label] in the navigation rail.
Future<void> openPage(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Job testJob(
  String id, {
  required String title,
  String company = 'Acme',
  String location = '',
  String jobType = '',
  SalaryRange? salary,
  String descriptionHtml = '<p>Description</p>',
  Duration age = const Duration(hours: 2),
}) => Job(
  id: 'remoteok:$id',
  sourceId: 'remoteok',
  title: title,
  company: company,
  url: 'https://remoteok.com/remote-jobs/$id',
  location: location,
  jobType: jobType,
  salary: salary?.label ?? '',
  salaryRange: salary,
  descriptionHtml: descriptionHtml,
  publishedAt: DateTime.now().subtract(age),
);
