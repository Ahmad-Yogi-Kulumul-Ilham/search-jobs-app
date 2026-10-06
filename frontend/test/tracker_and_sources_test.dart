import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support.dart';

const _ashbyBody = '''
{"apiVersion": "1", "jobs": [
  {"id": "7458", "title": "Support Engineer", "team": "Support",
   "employmentType": "FullTime", "location": "Remote - Worldwide",
   "publishedAt": "2026-10-04T14:29:08.532+00:00",
   "isListed": true, "isRemote": true,
   "jobUrl": "https://jobs.ashbyhq.com/linear/7458",
   "descriptionHtml": "<p>Help customers</p>"}
]}
''';

void main() {
  testWidgets('adds a manual application and moves it between columns', (
    tester,
  ) async {
    final services = testServices(tester);
    await pumpApp(tester, services);

    await openPage(tester, 'Lamaran');
    expect(
      find.textContaining('Belum ada lowongan yang dilacak'),
      findsOneWidget,
    );

    await tester.tap(find.text('Tambah manual'));
    await tester.pumpAndSettle();
    // Submitting without a position is refused.
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Posisi wajib diisi'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Posisi'),
      'Data Analyst',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Perusahaan'),
      'Initech',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('Dilamar · 1'), findsOneWidget);
    expect(find.text('Data Analyst'), findsOneWidget);

    await tester.tap(find.byTooltip('Pindahkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pindah ke Interview'));
    await tester.pumpAndSettle();
    expect(find.text('Interview · 1'), findsOneWidget);
    expect(find.text('Dilamar · 0'), findsOneWidget);

    // Notes are edited in the card's dialog.
    await tester.tap(find.text('Data Analyst'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Catatan'),
      'Call Friday',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Call Friday'), findsOneWidget);
    expect(services.database.applications.all().single.notes, 'Call Friday');
  });

  testWidgets('switching a source off hides its jobs', (tester) async {
    await pumpApp(
      tester,
      testServices(tester, jobs: [testJob('1', title: 'Rust Engineer')]),
    );
    expect(find.text('Rust Engineer'), findsOneWidget);

    await openPage(tester, 'Sumber');
    expect(find.textContaining('1 lowongan · diperbarui'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Remote OK'));
    await tester.pumpAndSettle();

    await openPage(tester, 'Lowongan');
    expect(find.text('Rust Engineer'), findsNothing);
    expect(find.textContaining('0 lowongan'), findsOneWidget);
  });

  testWidgets('adds a company board after checking it, then lists its jobs', (
    tester,
  ) async {
    var boardWorks = false;
    final services = testServices(
      tester,
      onRequest: (request) {
        if (request.url.host != 'api.ashbyhq.com') return null;
        expect(request.url.path, '/posting-api/job-board/linear');
        return boardWorks
            ? http.Response(_ashbyBody, 200)
            : http.Response('Not found', 404);
      },
    );
    await pumpApp(tester, services);

    await openPage(tester, 'Sumber');
    await tester.tap(find.text('Tambah sumber'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Alamat'),
      'https://jobs.ashbyhq.com/linear',
    );
    await tester.pumpAndSettle();
    expect(find.text('Terdeteksi: Ashby'), findsOneWidget);

    // A board that does not answer is reported and not stored.
    await tester.tap(find.text('Periksa dan tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Sumber tidak bisa dibaca: HTTP 404'), findsOneWidget);
    expect(services.database.sources.custom(), isEmpty);

    boardWorks = true;
    await tester.tap(find.text('Periksa dan tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Linear'), findsOneWidget);
    expect(find.textContaining('Ashby · 1 lowongan'), findsOneWidget);

    await openPage(tester, 'Lowongan');
    expect(find.text('Support Engineer'), findsOneWidget);
    expect(find.text('Linear · Remote - Worldwide'), findsOneWidget);
  });
}
