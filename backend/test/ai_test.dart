import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';
import 'package:test/test.dart';

/// A minimal Word document with the given paragraphs.
Uint8List docx(List<String> paragraphs) {
  final body = paragraphs
      .map(
        (p) =>
            '<w:p><w:r><w:t xml:space="preserve">${const HtmlEscape().convert(p)}</w:t></w:r></w:p>',
      )
      .join();
  final xml =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$body<w:p><w:r><w:t>A</w:t><w:tab/><w:t>B</w:t></w:r></w:p></w:body>'
      '</w:document>';
  final archive = Archive()
    ..add(ArchiveFile.bytes('word/document.xml', utf8.encode(xml)));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

final _pdf = Uint8List.fromList(utf8.encode('%PDF-1.7\n% fake pdf for tests'));

const _job = Job(
  id: 'remoteok:1',
  sourceId: 'remoteok',
  title: 'Flutter Developer',
  company: 'Acme',
  url: 'https://remoteok.com/remote-jobs/1',
  location: 'Worldwide',
);

const _reviewJson = {
  'score': 82,
  'verdict': 'Cocok untuk peran ini.',
  'strengths': ['3 tahun Flutter'],
  'gaps': ['Belum ada pengalaman GraphQL'],
  'missing_keywords': ['Riverpod'],
  'suggestions': [
    {
      'section': 'Ringkasan',
      'original': 'Mobile developer.',
      'revised': 'Flutter developer with 3 years of production apps.',
      'reason': 'Menonjolkan Flutter.',
    },
  ],
  'location_check': 'Terbuka untuk seluruh dunia.',
};

http.Response _messageResponse(
  Object json, {
  String stopReason = 'end_turn',
  String model = 'claude-opus-5-5',
}) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'id': 'msg_1',
      'type': 'message',
      'role': 'assistant',
      'model': model,
      'stop_reason': stopReason,
      'content': [
        {'type': 'thinking', 'thinking': '', 'signature': 'x'},
        {'type': 'text', 'text': jsonEncode(json)},
      ],
      'usage': {
        'input_tokens': 10000,
        'output_tokens': 2000,
        'cache_read_input_tokens': 0,
      },
    }),
  ),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('docxText reads paragraphs and tabs', () {
    expect(
      docxText(docx(['Budi Santoso', 'Flutter & Dart · 3 tahun'])),
      'Budi Santoso\nFlutter & Dart · 3 tahun\nA\tB',
    );
    expect(() => docxText(utf8.encode('not a zip')), throwsFormatException);
  });

  group('CvStore', () {
    late AppDatabase database;
    final now = DateTime(2026, 10, 7);

    setUp(() => database = AppDatabase.inMemory());
    tearDown(() => database.close());

    test('stores PDF, DOCX, and text CVs and rejects other files', () {
      final cvs = database.cvs;
      final pdf = cvs.add(
        name: 'CV PDF',
        fileName: 'cv.pdf',
        bytes: _pdf,
        now: now,
      );
      final word = cvs.add(
        name: 'CV Word',
        fileName: 'CV.DOCX',
        bytes: docx(['Budi']),
        now: now.add(const Duration(minutes: 1)),
      );

      expect(pdf.format, CvFormat.pdf);
      expect(pdf.text, isEmpty);
      expect(word.format, CvFormat.docx);
      expect(word.text, startsWith('Budi'));
      expect(cvs.all().map((cv) => cv.name), ['CV Word', 'CV PDF']);
      expect(cvs.find(pdf.id)!.bytes, _pdf);

      expect(
        () => cvs.add(
          name: 'x',
          fileName: 'cv.pdf',
          bytes: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
          now: now,
        ),
        throwsFormatException,
      );
      expect(
        () => cvs.add(name: 'x', fileName: 'cv.jpg', bytes: _pdf, now: now),
        throwsFormatException,
      );
      expect(
        () => cvs.add(
          name: 'x',
          fileName: 'cv.txt',
          bytes: Uint8List(0),
          now: now,
        ),
        throwsFormatException,
      );
    });

    test('reviews give jobs a match score and go with their CV', () {
      database.jobs.saveFetch('remoteok', [_job], now);
      final first = database.cvs.add(
        name: 'A',
        fileName: 'a.pdf',
        bytes: _pdf,
        now: now,
      );
      final second = database.cvs.add(
        name: 'B',
        fileName: 'b.pdf',
        bytes: _pdf,
        now: now,
      );
      expect(database.jobs.find(_job.id)!.matchScore, isNull);

      for (final (cv, score) in [(first, 64), (second, 82)]) {
        database.cvs.saveReview(
          StoredReview(
            jobId: _job.id,
            cvId: cv.id,
            review: CvReview.fromJson({..._reviewJson, 'score': score}),
            model: 'claude-opus-5-5',
            costUsd: 0.08,
            createdAt: now,
          ),
        );
      }
      expect(database.jobs.find(_job.id)!.matchScore, 82);
      expect(database.cvs.reviewsFor(_job.id), hasLength(2));
      final stored = database.cvs.reviewsFor(_job.id).first.review;
      expect(stored.suggestions.single.revised, contains('Flutter developer'));

      database.cvs.delete(second.id);
      expect(database.jobs.find(_job.id)!.matchScore, 64);
    });

    test('answers and AI spending', () {
      database.cvs.saveAnswer(
        question: 'Why us?',
        answer: 'Because…',
        now: now,
      );
      final saved = database.cvs.answers().single;
      database.cvs.saveAnswer(
        id: saved.id,
        question: 'Why us?',
        answer: 'Updated',
        now: now,
      );
      expect(database.cvs.answers().single.answer, 'Updated');
      database.cvs.deleteAnswer(saved.id);
      expect(database.cvs.answers(), isEmpty);

      database.cvs.recordSpend(0.08, now);
      database.cvs.recordSpend(0.02, now);
      expect(database.cvs.totalCostUsd(), closeTo(0.10, 1e-9));
    });
  });

  group('ClaudeClient', () {
    test('sends a structured-output request and reads the answer', () async {
      late Map<String, Object?> sent;
      late Map<String, String> headers;
      final client = ClaudeClient(
        apiKey: 'sk-test',
        model: AiModel.opus,
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, Object?>;
          headers = request.headers;
          return _messageResponse(_reviewJson);
        }),
      );
      final reviewer = CvReviewer(client);
      final cv = Cv(
        id: 1,
        name: 'CV',
        fileName: 'cv.pdf',
        format: CvFormat.pdf,
        bytes: _pdf,
        text: '',
        createdAt: DateTime(2026),
      );

      final (review, usage) = await reviewer.review(
        cv: cv,
        job: _job,
        jobDescription: 'We need Flutter.',
      );

      expect(headers['x-api-key'], 'sk-test');
      expect(headers['anthropic-version'], '2023-06-01');
      expect(headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
      expect(sent['model'], 'claude-opus-5-5');
      expect(sent['fallbacks'], 'default');
      expect(sent.containsKey('thinking'), isFalse);
      final config = sent['output_config'] as Map;
      expect(config['effort'], 'high');
      expect((config['format'] as Map)['type'], 'json_schema');
      final content =
          ((sent['messages'] as List).single as Map)['content'] as List;
      final cvSource = (content[0] as Map)['source'] as Map;
      expect(cvSource['type'], 'base64');
      expect(cvSource['media_type'], 'application/pdf');
      expect(base64Decode(cvSource['data'] as String), _pdf);
      final jobSource = (content[1] as Map)['source'] as Map;
      expect(jobSource['data'], contains('We need Flutter.'));
      expect(sent['system'], contains('Never add experience'));

      expect(review.score, 82);
      expect(review.missingKeywords, ['Riverpod']);
      expect(usage.model, 'claude-opus-5-5');
      // 10k input at \$4/M plus 2k output at \$20/M.
      expect(usage.costUsd, closeTo(0.08, 1e-9));
    });

    test(
      'Haiku gets neither effort nor fallbacks; DOCX goes as text',
      () async {
        late Map<String, Object?> sent;
        late Map<String, String> headers;
        final reviewer = CvReviewer(
          ClaudeClient(
            apiKey: 'sk-test',
            model: AiModel.haiku,
            client: MockClient((request) async {
              sent = jsonDecode(request.body) as Map<String, Object?>;
              headers = request.headers;
              return _messageResponse({'answer': 'I like your product.'});
            }),
          ),
        );
        final cv = Cv(
          id: 1,
          name: 'CV',
          fileName: 'cv.docx',
          format: CvFormat.docx,
          bytes: Uint8List(0),
          text: 'Budi Santoso, Flutter developer',
          createdAt: DateTime(2026),
        );

        final (answer, _) = await reviewer.draftAnswer(
          cv: cv,
          question: 'Why us?',
        );

        expect(answer, 'I like your product.');
        expect(sent['model'], 'claude-haiku-4-5');
        expect(sent.containsKey('fallbacks'), isFalse);
        expect(headers.containsKey('anthropic-beta'), isFalse);
        expect((sent['output_config'] as Map).containsKey('effort'), isFalse);
        final content =
            ((sent['messages'] as List).single as Map)['content'] as List;
        expect(
          ((content.first as Map)['source'] as Map)['data'],
          'Budi Santoso, Flutter developer',
        );
        expect((content.last as Map)['text'], 'Question:\nWhy us?');
      },
    );

    test('turns failures into readable messages', () async {
      Future<String> failure(http.Response response) async {
        final client = ClaudeClient(
          apiKey: 'sk-test',
          model: AiModel.sonnet,
          client: MockClient((_) async => response),
        );
        try {
          await client.createJson(
            system: 's',
            content: const [],
            schema: const {},
          );
          fail('expected an AiException');
        } on AiException catch (error) {
          return error.message;
        }
      }

      expect(
        await failure(
          http.Response(
            '{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}',
            401,
          ),
        ),
        contains('API key ditolak'),
      );
      expect(
        await failure(
          http.Response(
            '{"type":"error","error":{"type":"rate_limit_error","message":"slow down"}}',
            429,
          ),
        ),
        contains('saldo'),
      );
      expect(
        await failure(
          http.Response(
            '{"type":"error","error":{"type":"overloaded_error","message":"busy"}}',
            529,
          ),
        ),
        contains('sibuk'),
      );
      expect(
        await failure(
          http.Response(
            '{"type":"error","error":{"type":"invalid_request_error","message":"bad field"}}',
            400,
          ),
        ),
        'Permintaan ke Claude gagal (HTTP 400): bad field',
      );
      expect(
        await failure(_messageResponse(const {}, stopReason: 'refusal')),
        contains('menolak'),
      );
      expect(
        await failure(_messageResponse(const {}, stopReason: 'max_tokens')),
        contains('terpotong'),
      );
      expect(
        await failure(http.Response('<html>', 502)),
        contains('tidak terbaca'),
      );
    });
  });
}
