import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:search_jobs_app/notifier.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import 'support.dart';

const _ashbyBody = '''
{"apiVersion": "1", "jobs": [
  {"id": "1", "title": "Support Engineer", "employmentType": "FullTime",
   "location": "Remote - Worldwide", "isListed": true, "isRemote": true,
   "jobUrl": "https://jobs.ashbyhq.com/linear/1", "descriptionHtml": "<p>Help</p>"},
  {"id": "2", "title": "Product Designer", "employmentType": "FullTime",
   "location": "Remote - Worldwide", "isListed": true, "isRemote": true,
   "jobUrl": "https://jobs.ashbyhq.com/linear/2", "descriptionHtml": "<p>Design</p>"}
]}
''';

void main() {
  testWidgets('new jobs matching a saved search are announced', (tester) async {
    final notifier = RecordingNotifier();
    final services = testServices(
      tester,
      notifier: notifier,
      onRequest: (request) => request.url.host == 'api.ashbyhq.com'
          ? http.Response(_ashbyBody, 200)
          : null,
    );
    services.database.alerts.add('Support', const JobFilter(query: 'support'));
    // A source that was never fetched, so the refresh at startup reads it.
    services.database.sources.addCustom(
      kind: CustomSourceKind.ashby,
      name: 'Linear',
      value: 'linear',
    );

    await pumpApp(tester, services);

    expect(notifier.shown.map((a) => a.title), ['1 lowongan baru: Support']);
    expect(notifier.shown.single.body, 'Support Engineer · Linear');
  });

  testWidgets('saves the current search from the jobs page', (tester) async {
    final services = testServices(
      tester,
      jobs: [testJob('1', title: 'Flutter Developer')],
    );
    await pumpApp(tester, services);

    await tester.tap(find.byTooltip('Pencarian tersimpan'));
    await tester.pumpAndSettle();
    expect(
      find.text('Isi pencarian atau filter dulu untuk menyimpannya'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(900, 600));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.tap(find.widgetWithText(FilterChip, 'Ada gaji'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Pencarian tersimpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan pencarian ini sebagai peringatan…'));
    await tester.pumpAndSettle();

    expect(find.text('Filter: "flutter" · ada gaji'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    final alert = services.database.alerts.all().single;
    expect(alert.name, 'flutter');
    expect(alert.filter.withSalaryOnly, isTrue);

    await openPage(tester, 'Pengaturan');
    expect(find.text('"flutter" · ada gaji'), findsOneWidget);
  });

  testWidgets('a quiet application shows a reminder until followed up', (
    tester,
  ) async {
    final notifier = RecordingNotifier();
    final services = testServices(tester, notifier: notifier);
    services.database.applications.addManual(
      title: 'Data Analyst',
      company: 'Initech',
      url: '',
      status: ApplicationStatus.applied,
      now: DateTime.now().subtract(const Duration(days: 8)),
    );
    await pumpApp(tester, services);

    expect(notifier.shown.single.title, 'Saatnya follow-up');
    final badge = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.byType(Badge),
    );
    expect(
      tester.widgetList<Badge>(badge).where((b) => b.isLabelVisible),
      hasLength(1),
    );

    await openPage(tester, 'Lamaran');
    expect(find.text('Perlu ditindaklanjuti'), findsOneWidget);
    expect(
      find.textContaining('Belum ada kabar 8 hari sejak melamar'),
      findsOneWidget,
    );

    await tester.tap(find.text('Sudah follow-up'));
    await tester.pumpAndSettle();
    expect(find.text('Perlu ditindaklanjuti'), findsNothing);
    expect(
      tester.widgetList<Badge>(badge).where((b) => b.isLabelVisible),
      isEmpty,
    );
  });

  testWidgets('turning notifications off keeps reminders in the app only', (
    tester,
  ) async {
    final notifier = RecordingNotifier();
    final services = testServices(tester, notifier: notifier);
    services.notificationsEnabled = false;
    services.database.applications.addManual(
      title: 'Data Analyst',
      company: 'Initech',
      url: '',
      status: ApplicationStatus.applied,
      now: DateTime.now().subtract(const Duration(days: 8)),
    );
    await pumpApp(tester, services);

    expect(notifier.shown, isEmpty);
    await openPage(tester, 'Lamaran');
    expect(find.text('Perlu ditindaklanjuti'), findsOneWidget);
  });

  testWidgets('suspicious postings are marked in the list and detail', (
    tester,
  ) async {
    await pumpApp(
      tester,
      testServices(
        tester,
        jobs: [
          testJob(
            '1',
            title: 'Remote Assistant',
            descriptionHtml: '<p>Contact our manager on Telegram today.</p>',
          ),
          testJob('2', title: 'Engineer'),
        ],
      ),
    );

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    await tester.tap(find.text('Remote Assistant'));
    await tester.pumpAndSettle();
    expect(find.text('Lowongan ini perlu dicek dengan teliti'), findsOneWidget);
    expect(
      find.text('• Kontak hanya lewat Telegram atau WhatsApp'),
      findsOneWidget,
    );

    await tester.tap(find.text('Engineer'));
    await tester.pumpAndSettle();
    expect(find.text('Lowongan ini perlu dicek dengan teliti'), findsNothing);
  });
}
