import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:search_jobs_app/app_services.dart';
import 'package:search_jobs_app/file_picking.dart';
import 'package:search_jobs_app/form_browser.dart';
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
  Future<http.Response> Function(http.Request request)? onClaude,
  Future<PickedFile?> Function()? chooseCvFile,
  FormBrowser Function()? createBrowser,
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
    aiHttpClient: MockClient(
      onClaude ?? (request) async => fail('unexpected Claude request'),
    ),
    chooseCvFile: chooseCvFile ?? () async => null,
    createBrowser: createBrowser ?? FakeFormBrowser.new,
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

/// Stands in for the in-app browser. Fill scripts get [fillResult]; answer
/// scripts report that the field was found.
class FakeFormBrowser implements FormBrowser {
  FakeFormBrowser({this.fillResult, this.failToStart = false});

  final Object? fillResult;
  final bool failToStart;
  final opened = <String>[];
  final scripts = <String>[];
  final _url = StreamController<String>.broadcast();
  final _loading = StreamController<bool>.broadcast();

  @override
  Future<void> initialize() async {
    if (failToStart) throw Exception('WebView2 missing');
  }

  @override
  Future<void> open(String url) async {
    opened.add(url);
    _url.add(url);
  }

  @override
  Future<Object?> run(String script) async {
    scripts.add(script);
    return script.contains('data-sja-question="') &&
            !script.contains('const data')
        ? true
        : fillResult;
  }

  @override
  Future<void> back() async {}

  @override
  Future<void> reload() async {}

  @override
  Stream<String> get url => _url.stream;

  @override
  Stream<bool> get loading => _loading.stream;

  @override
  Widget view() => const ColoredBox(
    color: Color(0xFFEEEEEE),
    child: Center(child: Text('BROWSER')),
  );

  @override
  Future<void> dispose() async {
    await _url.close();
    await _loading.close();
  }
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
