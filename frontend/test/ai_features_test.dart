import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:search_jobs_app/secret_box.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import 'support.dart';

final _pdf = Uint8List.fromList(utf8.encode('%PDF-1.7\n% test CV'));

const _reviewJson = {
  'score': 82,
  'verdict': 'CV ini cocok untuk posisi Flutter.',
  'strengths': ['3 tahun membangun aplikasi Flutter'],
  'gaps': ['Belum terlihat pengalaman GraphQL'],
  'missing_keywords': ['Riverpod'],
  'suggestions': [
    {
      'section': 'Ringkasan',
      'original': 'Mobile developer.',
      'revised': 'Flutter developer with 3 years of production apps.',
      'reason': 'Menonjolkan Flutter sejak kalimat pertama.',
    },
  ],
  'location_check': 'Lowongan terbuka untuk seluruh dunia.',
};

http.Response claudeAnswer(Object json) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'model': 'claude-opus-5-5',
      'stop_reason': 'end_turn',
      'content': [
        {'type': 'text', 'text': jsonEncode(json)},
      ],
      'usage': {'input_tokens': 10000, 'output_tokens': 2000},
    }),
  ),
  200,
);

void main() {
  testWidgets('uploads a CV and refuses files it cannot read', (tester) async {
    var file = (name: 'Budi CV.pdf', bytes: _pdf);
    final services = testServices(tester, chooseCvFile: () async => file);
    await pumpApp(tester, services);

    await openPage(tester, 'CV');
    expect(find.textContaining('Belum ada CV'), findsOneWidget);
    await tester.tap(find.text('Unggah CV'));
    await tester.pumpAndSettle();
    expect(find.text('Budi CV'), findsOneWidget);
    expect(find.textContaining('Budi CV.pdf · diunggah'), findsOneWidget);

    file = (name: 'photo.png', bytes: _pdf);
    await tester.tap(find.text('Unggah CV'));
    await tester.pumpAndSettle();
    expect(
      find.text('Format tidak didukung. Pakai PDF atau DOCX.'),
      findsOneWidget,
    );
    expect(services.database.cvs.all(), hasLength(1));
  });

  testWidgets('stores the API key and shows only its end', (tester) async {
    final services = testServices(tester);
    await pumpApp(tester, services);
    await openPage(tester, 'Pengaturan');

    await tester.enterText(
      find.widgetWithText(TextField, 'API key Anthropic'),
      'abc',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('diawali "sk-ant-"'), findsOneWidget);
    expect(services.apiKey, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'API key Anthropic'),
      ' sk-ant-api03-secret-WXYZ ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(services.apiKey, 'sk-ant-api03-secret-WXYZ');
    expect(find.text('API key tersimpan: sk-ant-…WXYZ'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect(services.apiKey, isNull);
  });

  testWidgets('switches to Gemini with its own key and reviews with it', (
    tester,
  ) async {
    Uri? url;
    final services = testServices(
      tester,
      jobs: [testJob('1', title: 'Flutter Developer', location: 'Worldwide')],
      onClaude: (http.Request sent) async {
        url = sent.url;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {'text': jsonEncode(_reviewJson)},
                    ],
                  },
                },
              ],
              'usageMetadata': {
                'promptTokenCount': 10000,
                'candidatesTokenCount': 2000,
              },
            }),
          ),
          200,
        );
      },
    );
    services.database.cvs.add(
      name: 'CV Utama',
      fileName: 'cv.pdf',
      bytes: _pdf,
      now: DateTime.now(),
    );
    services.setApiKey('sk-ant-old-key1');
    await pumpApp(tester, services);
    await openPage(tester, 'Pengaturan');

    await tester.tap(find.byType(DropdownMenu<AiProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini (Google)').last);
    await tester.pumpAndSettle();
    expect(services.aiModel, AiModel.gemini38Flash);
    // The Anthropic key stays saved but is not the one in use.
    expect(services.apiKey, isNull);
    expect(services.apiKeyFor(AiProvider.anthropic), 'sk-ant-old-key1');

    final keyField = find.widgetWithText(TextField, 'API key Google Gemini');
    await tester.enterText(keyField, 'sk-proj-wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('diawali "AIza"'), findsOneWidget);

    await tester.enterText(keyField, 'AIzaSyTest1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('API key tersimpan: AIza…1234'), findsOneWidget);
    expect(services.apiKey, 'AIzaSyTest1234');

    await openPage(tester, 'Lowongan');
    await tester.tap(find.text('Flutter Developer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review dengan AI'));
    await tester.pumpAndSettle();

    expect(url!.path, '/v1beta/models/gemini-3.8-flash:generateContent');
    expect(find.text('82%'), findsNWidgets(2));
    // 10k input at USD 0,75/M plus 2k output at USD 3,75/M.
    expect(services.database.cvs.totalCostUsd(), closeTo(0.015, 1e-9));
  });

  testWidgets('OpenRouter needs a model id before reviews can run', (
    tester,
  ) async {
    final services = testServices(tester);
    await pumpApp(tester, services);
    await openPage(tester, 'Pengaturan');

    await tester.tap(find.byType(DropdownMenu<AiProvider>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('OpenRouter (').last);
    await tester.pumpAndSettle();
    services.setApiKey('sk-or-v1-test');
    await tester.pumpAndSettle();
    expect(services.aiReady, isFalse);

    final modelField = find.widgetWithText(TextField, 'ID model OpenRouter');
    await tester.enterText(modelField, 'deepseek');
    await tester.tap(find.text('Pakai model'));
    await tester.pumpAndSettle();
    expect(find.textContaining('berbentuk penyedia/nama'), findsOneWidget);

    await tester.enterText(modelField, 'deepseek/deepseek-chat');
    await tester.tap(find.text('Pakai model'));
    await tester.pumpAndSettle();
    expect(services.openRouterModel, 'deepseek/deepseek-chat');
    expect(services.aiReady, isTrue);
    expect(services.reviewer()!.provider, AiProvider.openrouter);
  });

  testWidgets('practises interview questions, and rates an answer', (
    tester,
  ) async {
    final asked = <String>[];
    final services = testServices(
      tester,
      jobs: [testJob('1', title: 'Flutter Developer', location: 'Worldwide')],
      onClaude: (http.Request sent) async {
        final body = jsonDecode(sent.body) as Map<String, Object?>;
        final content =
            ((body['messages'] as List).single as Map)['content'] as List;
        final prompt = (content.last as Map)['text'] as String;
        asked.add(prompt);
        if (prompt.contains('My answer:')) {
          return claudeAnswer({
            'rating': 3,
            'summary': 'Sudah menjawab, tapi belum ada contoh nyata.',
            'strengths': ['Singkat dan jelas'],
            'improvements': ['Sebutkan jam overlap yang pasti'],
            'improved_answer': 'I keep a [4-hour] overlap with the team.',
          });
        }
        return claudeAnswer({
          'overview': 'Interview akan fokus pada Flutter dan kerja remote.',
          'questions': [
            {
              'kind': 'remote',
              'question': 'How do you work across time zones?',
              'why': 'Timnya tersebar di banyak zona waktu.',
              'tips': 'Sebutkan jam kerja dan cara berkomunikasi.',
              'sample_answer': 'I plan my day around a shared overlap…',
            },
          ],
          'questions_to_ask': ['How is the team spread across time zones?'],
          'to_prepare': ['Hitung selisih waktu dengan kantor pusat.'],
        });
      },
    );
    services.database.cvs.add(
      name: 'CV Utama',
      fileName: 'cv.pdf',
      bytes: _pdf,
      now: DateTime.now(),
    );
    services.setApiKey('sk-ant-test');
    await pumpApp(tester, services);

    await tester.tap(find.text('Flutter Developer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latihan interview'));
    await tester.pumpAndSettle();

    expect(asked, ['Prepare me for the interviews for this job.']);
    expect(find.text('Kerja remote'), findsOneWidget);
    expect(
      find.text('Hitung selisih waktu dengan kantor pusat.'),
      findsNothing,
    );
    expect(find.textContaining('Hitung selisih waktu'), findsOneWidget);

    await tester.tap(find.text('How do you work across time zones?'));
    await tester.pumpAndSettle();
    expect(find.text('I plan my day around a shared overlap…'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Tulis seperti Anda akan mengucapkannya…'),
      'I am flexible with hours.',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Nilai jawaban'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nilai jawaban'));
    await tester.pumpAndSettle();

    expect(asked.last, contains('My answer:\nI am flexible with hours.'));
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('• Sebutkan jam overlap yang pasti'), findsOneWidget);
    expect(
      find.text('I keep a [4-hour] overlap with the team.'),
      findsOneWidget,
    );

    // Reopening shows the saved questions without asking the AI again.
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latihan interview'));
    await tester.pumpAndSettle();
    expect(find.text('How do you work across time zones?'), findsOneWidget);
    expect(asked, hasLength(2));
  });

  testWidgets('reopening interview practice while it is being made does '
      'not pay twice', (tester) async {
    final answer = Completer<http.Response>();
    var requests = 0;
    final services = testServices(
      tester,
      jobs: [testJob('1', title: 'Flutter Developer')],
      onClaude: (_) {
        requests++;
        return answer.future;
      },
    );
    services.database.cvs.add(
      name: 'CV Utama',
      fileName: 'cv.pdf',
      bytes: _pdf,
      now: DateTime.now(),
    );
    services.setApiKey('sk-ant-test');
    await pumpApp(tester, services);
    await tester.tap(find.text('Flutter Developer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Latihan interview'));
    await tester.pump();
    expect(find.textContaining('sedang menyiapkan pertanyaan'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latihan interview'));
    await tester.pump();
    expect(find.textContaining('sedang menyiapkan pertanyaan'), findsOneWidget);

    answer.complete(
      claudeAnswer({
        'overview': 'Fokus pada Flutter.',
        'questions': [
          {
            'kind': 'technical',
            'question': 'Why Flutter?',
            'why': '-',
            'tips': '-',
            'sample_answer': '-',
          },
        ],
        'questions_to_ask': <String>[],
        'to_prepare': <String>[],
      }),
    );
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(find.text('Why Flutter?'), findsOneWidget);
    // 10k input and 2k output tokens on Opus, billed once.
    expect(services.database.cvs.totalCostUsd(), closeTo(0.08, 1e-9));
  });

  testWidgets('reviews a CV against a job and shows the score', (tester) async {
    Map<String, Object?>? request;
    final services = testServices(
      tester,
      jobs: [
        testJob(
          '1',
          title: 'Flutter Developer',
          location: 'Worldwide',
          descriptionHtml: '<p>We need <b>Flutter</b> and Riverpod.</p>',
        ),
      ],
      onClaude: (http.Request sent) async {
        request = jsonDecode(sent.body) as Map<String, Object?>;
        return claudeAnswer(_reviewJson);
      },
    );
    services.database.cvs.add(
      name: 'CV Utama',
      fileName: 'cv.pdf',
      bytes: _pdf,
      now: DateTime.now(),
    );
    services.setApiKey('sk-ant-test');
    await pumpApp(tester, services);

    await tester.tap(find.text('Flutter Developer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review dengan AI'));
    await tester.pumpAndSettle();

    final content =
        ((request!['messages'] as List).single as Map)['content'] as List;
    expect(
      ((content[1] as Map)['source'] as Map)['data'],
      contains('We need Flutter and Riverpod.'),
    );
    expect(find.text('82%'), findsNWidgets(2));
    expect(find.text('CV ini cocok untuk posisi Flutter.'), findsOneWidget);
    expect(find.text('• Belum terlihat pengalaman GraphQL'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Riverpod'), findsOneWidget);
    expect(
      find.text('Flutter developer with 3 years of production apps.'),
      findsOneWidget,
    );
    expect(find.text('Review ulang'), findsOneWidget);
    // 10k input and 2k output tokens on Opus: USD 0,080, at Rp 18.000.
    expect(find.textContaining('USD 0,080 (≈ Rp 1.440)'), findsOneWidget);
    expect(services.database.cvs.totalCostUsd(), closeTo(0.08, 1e-9));
  });

  testWidgets('shows why a review failed', (tester) async {
    final services = testServices(
      tester,
      jobs: [testJob('1', title: 'Flutter Developer')],
      onClaude: (_) async => http.Response(
        '{"type":"error","error":{"type":"authentication_error",'
        '"message":"invalid x-api-key"}}',
        401,
      ),
    );
    services.database.cvs.add(
      name: 'CV',
      fileName: 'cv.pdf',
      bytes: _pdf,
      now: DateTime.now(),
    );
    services.setApiKey('sk-ant-wrong');
    await pumpApp(tester, services);

    await tester.tap(find.text('Flutter Developer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review dengan AI'));
    await tester.pumpAndSettle();

    expect(find.textContaining('API key ditolak'), findsOneWidget);
    expect(services.database.cvs.reviewsFor('remoteok:1'), isEmpty);
  });

  testWidgets('without a CV or key the panel explains what is missing', (
    tester,
  ) async {
    final services = testServices(
      tester,
      jobs: [testJob('1', title: 'Flutter Developer')],
    );
    await pumpApp(tester, services);
    await tester.tap(find.text('Flutter Developer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unggah CV Anda di halaman CV'), findsOneWidget);

    services.database.cvs.add(
      name: 'CV',
      fileName: 'cv.pdf',
      bytes: _pdf,
      now: DateTime.now(),
    );
    services.dataChanged();
    await tester.pumpAndSettle();
    expect(find.textContaining('Masukkan API key Claude'), findsOneWidget);
  });

  testWidgets('drafts a cover letter', (tester) async {
    final services = testServices(
      tester,
      jobs: [testJob('1', title: 'Flutter Developer')],
      onClaude: (_) async => claudeAnswer({
        'subject': 'Application: Flutter Developer',
        'letter': 'Dear Acme team, I build Flutter apps.',
      }),
    );
    services.database.cvs.add(
      name: 'CV',
      fileName: 'cv.pdf',
      bytes: _pdf,
      now: DateTime.now(),
    );
    services.setApiKey('sk-ant-test');
    await pumpApp(tester, services);

    await tester.tap(find.text('Flutter Developer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat cover letter'));
    await tester.pumpAndSettle();

    expect(find.text('Draf cover letter'), findsOneWidget);
    expect(find.text('Subjek: Application: Flutter Developer'), findsOneWidget);
    expect(find.text('Dear Acme team, I build Flutter apps.'), findsOneWidget);
  });

  testWidgets('saves an answer drafted by AI', (tester) async {
    final services = testServices(
      tester,
      onClaude: (_) async =>
          claudeAnswer({'answer': 'I enjoy building products people use.'}),
    );
    services.database.cvs.add(
      name: 'CV',
      fileName: 'cv.pdf',
      bytes: _pdf,
      now: DateTime.now(),
    );
    services.setApiKey('sk-ant-test');
    await pumpApp(tester, services);
    await openPage(tester, 'CV');

    await tester.tap(find.text('Tambah jawaban'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Pertanyaan'),
      'Why do you want to work here?',
    );
    await tester.tap(find.text('Buat draf dengan AI'));
    await tester.pumpAndSettle();
    expect(find.text('I enjoy building products people use.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Why do you want to work here?'), findsOneWidget);
    expect(
      services.database.cvs.answers().single.answer,
      'I enjoy building products people use.',
    );
  });

  test('DPAPI seals so that only this Windows user can open', () {
    final box = DpapiSecretBox();
    final sealed = box.seal('sk-ant-api03-secret');
    expect(sealed, isNot(contains('secret')));
    expect(box.open(sealed), 'sk-ant-api03-secret');
    expect(box.open('bm90IHNlYWxlZA=='), isNull);
    expect(box.open('%%%'), isNull);
  }, skip: !Platform.isWindows);
}
