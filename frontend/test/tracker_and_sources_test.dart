import 'dart:convert';

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

  testWidgets('adds a suggested source from "Temukan sumber"', (tester) async {
    var probes = 0;
    final services = testServices(
      tester,
      onRequest: (request) {
        if (request.url.host != 'api.ashbyhq.com') return null;
        probes++;
        return switch (request.url.path) {
          '/posting-api/job-board/linear' => http.Response(_ashbyBody, 200),
          _ => http.Response('Not found', 404),
        };
      },
    );
    await pumpApp(tester, services);

    await openPage(tester, 'Sumber');
    await tester.tap(find.text('Temukan sumber'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sering terbuka untuk Asia atau seluruh dunia'),
      findsOneWidget,
    );

    // Searching narrows the list.
    await tester.enterText(find.byType(TextField), 'supabase');
    await tester.pumpAndSettle();
    expect(find.text('Supabase'), findsOneWidget);
    expect(find.text('Canonical'), findsNothing);

    // A ticked board that does not answer shows why, and is not stored.
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Tambah yang dicentang (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Sumber tidak bisa dibaca: HTTP 404'), findsOneWidget);
    expect(services.database.sources.custom(), isEmpty);

    await tester.enterText(find.byType(TextField), 'linear');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Tambah yang dicentang (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Ditambahkan'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(services.database.sources.custom().single.value, 'linear');

    // Closing fetches the new source once more, into the list.
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(probes, 3);
    expect(find.textContaining('Ashby · 1 lowongan'), findsOneWidget);

    // Reopening marks it as already added.
    await tester.tap(find.text('Temukan sumber'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'linear');
    await tester.pumpAndSettle();
    expect(find.text('Ditambahkan'), findsOneWidget);
  });

  testWidgets('finds a board behind a company in stored jobs', (tester) async {
    final asked = <String>[];
    final services = testServices(
      tester,
      jobs: [testJob('1', title: 'Support Engineer', company: 'Acme')],
      onRequest: (request) {
        asked.add('${request.url.host}${request.url.path}');
        return request.url.path == '/posting-api/job-board/acme'
            ? http.Response(_ashbyBody, 200)
            : http.Response('Not found', 404);
      },
    );
    await pumpApp(tester, services);
    await openPage(tester, 'Sumber');
    await tester.tap(find.text('Temukan sumber'));
    await tester.pumpAndSettle();
    expect(find.text('Hasil penemuan'), findsNothing);

    await tester.tap(find.text('Cari dari lowongan'));
    await tester.pumpAndSettle();

    // Greenhouse and Lever have no "acme" board; Ashby does.
    expect(asked, [
      'boards-api.greenhouse.io/v1/boards/acme/jobs',
      'api.lever.co/v0/postings/acme',
      'api.ashbyhq.com/posting-api/job-board/acme',
    ]);
    expect(find.text('Hasil penemuan'), findsOneWidget);
    expect(find.text('Baru'), findsOneWidget);
    expect(
      find.text('Ashby · 1 lowongan remote, 1 bisa dari Indonesia'),
      findsOneWidget,
    );
    expect(
      find.text('1 sumber baru dari 1 perusahaan yang diperiksa.'),
      findsOneWidget,
    );

    // The same job title confirms it is the same company, and it has jobs
    // open to Indonesia, so it comes ticked.
    await tester.tap(find.text('Tambah yang dicentang (1)'));
    await tester.pumpAndSettle();
    expect(services.database.sources.custom().single.value, 'acme');
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ashby · 1 lowongan'), findsOneWidget);

    // Reopened, the board is a source now and is no longer offered.
    await tester.tap(find.text('Temukan sumber'));
    await tester.pumpAndSettle();
    expect(find.text('Hasil penemuan'), findsNothing);
  });

  testWidgets('an AI web search suggests sources, checked before shown', (
    tester,
  ) async {
    Map<String, Object?>? aiRequest;
    final services = testServices(
      tester,
      onRequest: (request) =>
          request.url.path == '/posting-api/job-board/linear'
          ? http.Response(_ashbyBody, 200)
          : http.Response('Not found', 404),
      onClaude: (request) async {
        aiRequest = jsonDecode(request.body) as Map<String, Object?>;
        final answer = {
          'sources': [
            {
              'name': 'Linear',
              'url': 'https://jobs.ashbyhq.com/linear',
              'reason': 'Merekrut remote di seluruh dunia.',
            },
            {'name': 'Gone', 'url': 'https://jobs.lever.co/gone'},
          ],
        };
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'model': 'claude-opus-5-5',
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'web_search_tool_result', 'tool_use_id': 's'},
                {'type': 'text', 'text': jsonEncode(answer)},
              ],
              'usage': {
                'input_tokens': 10000,
                'output_tokens': 1000,
                'server_tool_use': {'web_search_requests': 2},
              },
            }),
          ),
          200,
        );
      },
    );
    await pumpApp(tester, services);
    await openPage(tester, 'Sumber');
    await tester.tap(find.text('Temukan sumber'));
    await tester.pumpAndSettle();

    // Without an API key the AI search is off.
    final aiButton = find.widgetWithText(FilledButton, 'Cari dengan AI');
    expect(tester.widget<FilledButton>(aiButton).onPressed, isNull);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    services.setApiKey('sk-ant-test');

    await tester.tap(find.text('Temukan sumber'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'desain');
    await tester.tap(find.text('Cari dengan AI'));
    await tester.pumpAndSettle();

    expect(
      (aiRequest!['messages'] as List).single,
      containsPair('content', contains('desain')),
    );
    expect(
      find.text('Saran AI: Merekrut remote di seluruh dunia.'),
      findsOneWidget,
    );
    expect(find.textContaining('1 tidak bisa dibaca'), findsOneWidget);
    // 10k input at \$4/M, 1k output at \$20/M, and 2 searches at \$0.01.
    expect(services.database.cvs.totalCostUsd(), closeTo(0.08, 1e-9));
  });
}
