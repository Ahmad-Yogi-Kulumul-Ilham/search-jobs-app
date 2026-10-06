import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import 'support.dart';

const _fillReport = {
  'filled': ['firstName', 'lastName', 'email'],
  'resumeAttached': true,
  'resumeFieldFound': true,
  'questions': [
    {
      'index': 0,
      'label': 'Why do you want to work here?*',
      'required': true,
      'multiline': true,
    },
    {
      'index': 1,
      'label': 'What timezone are you in?',
      'required': false,
      'multiline': false,
    },
  ],
};

Future<void> _openApplyPage(WidgetTester tester, String jobTitle) async {
  await tester.tap(find.text(jobTitle));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Isi formulir di aplikasi'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fills the form, offers saved answers, and marks applied', (
    tester,
  ) async {
    final browser = FakeFormBrowser(fillResult: jsonEncode(_fillReport));
    final services = testServices(
      tester,
      jobs: [
        Job(
          id: 'remoteok:1',
          sourceId: 'remoteok',
          title: 'Flutter Developer',
          company: 'Acme',
          url: 'https://jobs.lever.co/acme/123',
          descriptionHtml: '<p>Flutter</p>',
          publishedAt: DateTime.now(),
        ),
      ],
      createBrowser: () => browser,
    );
    services.database.cvs.add(
      name: 'CV Utama',
      fileName: 'cv.pdf',
      bytes: Uint8List.fromList(utf8.encode('%PDF-1.7')),
      now: DateTime.now(),
    );
    services.database.cvs.saveAnswer(
      question: 'Why do you want to work here?',
      answer: 'I love building remote-first products.',
      now: DateTime.now(),
    );
    await pumpApp(tester, services);
    await _openApplyPage(tester, 'Flutter Developer');

    // Lever's form lives at the posting address plus /apply.
    expect(browser.opened, ['https://jobs.lever.co/acme/123/apply']);
    expect(find.text('BROWSER'), findsOneWidget);
    expect(find.text('Isi otomatis'), findsOneWidget);
    final fillButton = find.ancestor(
      of: find.text('Isi otomatis'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(fillButton).onPressed, isNull);

    // The profile is needed before filling.
    await tester.tap(find.text('Isi data pelamar dulu'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama lengkap'),
      'Budi Santoso',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'budi@');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Isi email yang valid'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'budi@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Budi Santoso · budi@example.com'), findsOneWidget);

    await tester.tap(find.text('Isi otomatis'));
    await tester.pumpAndSettle();
    final fill = browser.scripts.single;
    expect(fill, contains('"fullName":"Budi Santoso"'));
    expect(fill, contains('"name":"cv.pdf"'));
    expect(
      find.text('Terisi: nama depan, nama belakang, email.'),
      findsOneWidget,
    );
    expect(find.text('CV terlampir.'), findsOneWidget);
    expect(find.text('Why do you want to work here? (wajib)'), findsOneWidget);
    expect(find.text('Diambil dari bank jawaban'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'I love building remote-first products.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Isi ke formulir').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Isi ke formulir').first);
    await tester.pumpAndSettle();
    expect(
      browser.scripts.last,
      contains('"I love building remote-first products."'),
    );
    expect(find.text('Jawaban diisikan ke formulir.'), findsOneWidget);
    // Let the message slide away so it does not cover the panel's bottom.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Sudah saya kirim, tandai Dilamar'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah saya kirim, tandai Dilamar'));
    await tester.pumpAndSettle();
    final application = services.database.applications.find('remoteok:1')!;
    expect(application.status, ApplicationStatus.applied);
    expect(application.notes, contains('dengan CV "CV Utama"'));
    expect(find.text('BROWSER'), findsNothing);
    expect(find.text('Status: Dilamar'), findsOneWidget);
  });

  testWidgets('reports a page it cannot fill', (tester) async {
    final services = testServices(
      tester,
      jobs: [testJob('1', title: 'Writer')],
      createBrowser: () => FakeFormBrowser(fillResult: null),
    );
    services.applicantProfile = const ApplicantProfile(
      fullName: 'Budi',
      email: 'budi@example.com',
    );
    await pumpApp(tester, services);
    await _openApplyPage(tester, 'Writer');

    await tester.tap(find.text('Isi otomatis'));
    await tester.pumpAndSettle();
    expect(find.text('Halaman ini tidak bisa diisi otomatis.'), findsOneWidget);
  });

  testWidgets('explains when the in-app browser is unavailable', (
    tester,
  ) async {
    await pumpApp(
      tester,
      testServices(
        tester,
        jobs: [testJob('1', title: 'Writer')],
        createBrowser: () => FakeFormBrowser(failToStart: true),
      ),
    );
    await _openApplyPage(tester, 'Writer');

    expect(find.textContaining('WebView2 Runtime'), findsOneWidget);
  });
}
