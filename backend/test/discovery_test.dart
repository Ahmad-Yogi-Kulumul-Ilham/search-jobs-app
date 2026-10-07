import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';
import 'package:test/test.dart';

final _now = DateTime(2026, 10, 7, 9);

Job _job(String id, {required String title, required String company}) => Job(
  id: 'remoteok:$id',
  sourceId: 'remoteok',
  title: title,
  company: company,
  url: 'https://remoteok.com/remote-jobs/$id',
  location: 'Worldwide',
  descriptionHtml: id == '9'
      ? '<p>Apply at <a href="https://jobs.lever.co/initech/abc">Initech</a></p>'
      : '<p>x</p>',
);

String _ashby(List<(String, String)> jobs) => jsonEncode({
  'jobs': [
    for (final (title, location) in jobs)
      {
        'id': title,
        'title': title,
        'location': location,
        'isRemote': true,
        'isListed': true,
        'jobUrl': 'https://jobs.ashbyhq.com/x/$title',
      },
  ],
});

/// Stands in for a model that searched the web.
class _FakeAi implements AiClient {
  _FakeAi(this.answer);

  final Map<String, Object?> answer;
  String? prompt;

  @override
  AiProvider get provider => AiProvider.anthropic;

  @override
  Future<AiResult> searchJson({
    required String system,
    required String prompt,
    int maxSearches = 8,
  }) async {
    this.prompt = prompt;
    return AiResult(
      json: answer,
      model: 'claude-opus-5-5',
      inputTokens: 1,
      outputTokens: 1,
      costUsd: 0.05,
    );
  }

  @override
  Future<AiResult> createJson({
    required String system,
    required List<AiPart> content,
    required Map<String, Object?> schema,
    String effort = 'high',
    int maxTokens = 16000,
  }) => throw UnimplementedError();
}

void main() {
  test('board names to try for a company', () {
    expect(slugCandidates('Grafana Labs'), [
      'grafanalabs',
      'grafana-labs',
      'grafana',
    ]);
    expect(slugCandidates('Kong Inc.'), ['konginc', 'kong-inc', 'kong']);
    expect(slugCandidates('Stripe'), ['stripe']);
    expect(slugCandidates('株式会社'), isEmpty);
  });

  test('reads the board a link points at', () {
    expect(boardFromLink('https://jobs.lever.co/initech/abc/apply'), (
      kind: CustomSourceKind.lever,
      value: 'initech',
    ));
    expect(
      boardFromLink(
        'https://boards.greenhouse.io/embed/job_app?for=Globex&token=1',
      ),
      (kind: CustomSourceKind.greenhouse, value: 'globex'),
    );
    expect(boardFromLink('https://example.com/feed.xml'), isNull);
  });

  group('from stored jobs', () {
    late AppDatabase database;
    late List<Uri> requests;
    late SourceDiscovery discovery;

    setUp(() {
      database = AppDatabase.inMemory();
      requests = [];
      final client = MockClient((request) async {
        requests.add(request.url);
        final url = request.url.toString();
        if (url.startsWith(
          'https://api.ashbyhq.com/posting-api/job-board/acmelabs?',
        )) {
          return http.Response(
            _ashby([('Data Analyst', 'Remote - APAC'), ('Writer', 'US')]),
            200,
          );
        }
        if (url == 'https://boards-api.greenhouse.io/v1/boards/globex/jobs') {
          return http.Response(
            jsonEncode({
              'jobs': [
                {
                  'id': 1,
                  'title': 'Nurse',
                  'absolute_url': 'https://boards.greenhouse.io/globex/jobs/1',
                  'location': {'name': 'Remote, US'},
                },
              ],
            }),
            200,
          );
        }
        if (url == 'https://api.lever.co/v0/postings/initech?mode=json') {
          return http.Response(
            jsonEncode([
              {
                'id': 'a',
                'text': 'Support',
                'workplaceType': 'remote',
                'hostedUrl': 'https://jobs.lever.co/initech/a',
                'categories': {'location': 'Anywhere'},
              },
            ]),
            200,
          );
        }
        return http.Response('Not found', 404);
      });
      discovery = SourceDiscovery(
        database: database,
        fetch: (source) => source.fetch(client, listingOnly: true),
        clock: () => _now,
      );
      database.jobs.saveFetch('remoteok', [
        _job('1', title: 'Data Analyst', company: 'Acme Labs'),
        _job('2', title: 'Data Engineer', company: 'Acme Labs'),
        _job('3', title: 'Designer', company: 'Globex'),
        _job('4', title: 'Writer', company: 'Nobody Co'),
        _job('9', title: 'Support', company: 'Initech'),
      ], _now);
    });
    tearDown(() => database.close());

    test('finds boards by name and by link, and checks each once', () async {
      final progress = <int>[];
      final result = await discovery.fromJobs(
        onProgress: (done, total) => progress.add(total),
      );

      final found = {for (final s in database.discovery.all()) s.value: s};
      expect(found.keys, unorderedEquals(['acmelabs', 'globex', 'initech']));

      final acme = found['acmelabs']!;
      expect(acme.kind, CustomSourceKind.ashby);
      expect(acme.name, 'Acme Labs');
      expect(acme.origin, DiscoveryOrigin.company);
      expect(acme.verified, isTrue);
      expect(acme.remoteJobs, 2);
      expect(acme.openJobs, 1);
      // Same name, but none of its jobs match: maybe another company.
      expect(found['globex']!.verified, isFalse);
      expect(found['initech']!.origin, DiscoveryOrigin.link);

      // Greenhouse is asked for the light listing, without descriptions.
      expect(
        requests,
        contains(
          Uri.parse('https://boards-api.greenhouse.io/v1/boards/globex/jobs'),
        ),
      );
      expect(result.found, hasLength(3));
      expect(result.remainingCompanies, 0);
      expect(progress.last, result.checkedCompanies + 1);

      // A second run has nothing left to look up.
      requests.clear();
      final again = await discovery.fromJobs();
      expect(again.checkedCompanies, 0);
      expect(requests, isEmpty);
    });

    test('skips sources already added, dismissed, or blocked', () async {
      database.sources.addCustom(
        kind: CustomSourceKind.ashby,
        name: 'Acme Labs',
        value: 'acmelabs',
      );
      database.jobs.blockCompany('Globex');
      await discovery.fromJobs();

      expect(database.discovery.all().map((s) => s.value), ['initech']);
      expect(
        requests.where((u) => u.path.contains('globex')),
        isEmpty,
        reason: 'blocked companies are not looked up',
      );

      database.discovery.dismiss(CustomSourceKind.lever, 'initech');
      expect(database.discovery.all(), isEmpty);
    });
  });

  test('keeps only AI suggestions that answer with jobs', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    database.sources.addCustom(
      kind: CustomSourceKind.greenhouse,
      name: 'GitLab',
      value: 'gitlab',
    );
    final client = MockClient((request) async {
      final url = request.url.toString();
      if (url.startsWith(
        'https://api.ashbyhq.com/posting-api/job-board/newco?',
      )) {
        return http.Response(_ashby([('Engineer', 'Worldwide')]), 200);
      }
      if (url == 'https://feeds.example.com/Remote.xml') {
        return http.Response(
          '<rss><channel><item><title>Writer</title>'
          '<link>https://example.com/1</link></item></channel></rss>',
          200,
        );
      }
      return http.Response('Not found', 404);
    });
    final discovery = SourceDiscovery(
      database: database,
      fetch: (source) => source.fetch(client, listingOnly: true),
      clock: () => _now,
    );
    final ai = _FakeAi({
      'sources': [
        {
          'name': 'NewCo',
          'url': 'https://jobs.ashbyhq.com/newco',
          'reason': 'Merekrut dari mana saja.',
        },
        {
          'name': 'Remote Feed',
          'url': 'https://feeds.example.com/Remote.xml',
          'reason': 'Feed lowongan remote.',
        },
        {'name': 'Gone', 'url': 'https://jobs.lever.co/gone', 'reason': ''},
        {'name': 'GitLab', 'url': 'https://boards.greenhouse.io/gitlab'},
        {'name': 'Junk', 'url': 'not a link'},
      ],
    });

    final result = await discovery.withAi(ai, focus: 'data');

    expect(ai.prompt, contains('data'));
    expect(ai.prompt, contains('GitLab'));
    expect(result.suggested, 5);
    expect(result.unreadable, 2);
    expect(result.usage!.costUsd, 0.05);
    final found = database.discovery.all();
    expect(found.map((s) => s.name), unorderedEquals(['NewCo', 'Remote Feed']));
    final feed = found.firstWhere((s) => s.kind == CustomSourceKind.rss);
    // Feed addresses keep their case.
    expect(feed.value, 'https://feeds.example.com/Remote.xml');
    expect(feed.note, 'Feed lowongan remote.');
    expect(found.every((s) => s.origin == DiscoveryOrigin.ai), isTrue);
  });
}
