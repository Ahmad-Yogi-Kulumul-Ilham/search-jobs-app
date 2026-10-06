import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:search_jobs_app/main.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

void main() {
  testWidgets('lists stored jobs, filters them, and opens one', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final database = JobDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.now();
    // Every source counts as freshly fetched, so startup makes no requests.
    for (final source in allSources) {
      database.saveFetch(source.id, const [], now);
    }
    database.saveFetch('remoteok', [
      Job(
        id: 'remoteok:1',
        sourceId: 'remoteok',
        title: 'Rust Engineer',
        company: 'Fortanix',
        url: 'https://remoteok.com/remote-jobs/1',
        location: 'Worldwide',
        salary: 'USD 90.000 / tahun',
        tags: const ['rust', 'backend'],
        descriptionHtml: '<p>Build <b>secure</b> systems.</p>',
        publishedAt: now.subtract(const Duration(hours: 2)),
      ),
      Job(
        id: 'remoteok:2',
        sourceId: 'remoteok',
        title: 'Product Designer',
        company: 'Acme',
        url: 'https://remoteok.com/remote-jobs/2',
        descriptionHtml: '<p>Design things people love.</p>',
        publishedAt: now.subtract(const Duration(days: 3)),
      ),
    ], now);

    final repository = JobRepository(
      database: database,
      sources: allSources,
      client: MockClient((request) async {
        fail('unexpected request to ${request.url}');
      }),
    );

    await tester.pumpWidget(SearchJobsApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('2 lowongan'), findsOneWidget);
    expect(find.text('Rust Engineer'), findsOneWidget);
    expect(find.text('Fortanix · Worldwide'), findsOneWidget);
    expect(
      find.text('Pilih lowongan untuk melihat detailnya.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'designer');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('1 lowongan'), findsOneWidget);
    expect(find.text('Rust Engineer'), findsNothing);

    await tester.tap(find.text('Product Designer'));
    await tester.pumpAndSettle();

    expect(find.text('Lamar di Remote OK'), findsOneWidget);
    expect(
      find.textContaining('Design things people love', findRichText: true),
      findsOneWidget,
    );

    // Turning the only source with jobs off empties the list.
    await tester.tap(find.widgetWithText(FilterChip, 'Remote OK'));
    await tester.pumpAndSettle();

    expect(find.text('0 lowongan'), findsOneWidget);
    expect(find.text('Tidak ada lowongan yang cocok.'), findsOneWidget);
  });
}
