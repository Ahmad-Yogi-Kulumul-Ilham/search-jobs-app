import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';
import 'package:test/test.dart';

const _remoteOkBody = '''
[
  {"legal": "API Terms of Service"},
  {"id": "1", "epoch": 1791129603, "company": "Fortanix",
   "position": "Rust Engineer", "tags": ["rust", "backend"],
   "description": "<p>Rust</p>", "location": "Worldwide",
   "salary_min": 60000, "salary_max": 90000,
   "url": "https://remoteok.com/remote-jobs/1"},
  {"id": "2", "epoch": 1791129000, "company": "Acme",
   "position": "Product Designer", "tags": ["figma"],
   "description": "<p>Design</p>", "location": "Europe",
   "url": "https://remoteok.com/remote-jobs/2"}
]
''';

const _ratesBody =
    '{"amount": 1.0, "base": "USD", "date": "2026-10-05", '
    '"rates": {"IDR": 18000, "EUR": 0.9}}';

Job _job(
  String id, {
  String title = 'Engineer',
  String company = 'Acme',
  String location = '',
  String jobType = '',
  SalaryRange? salary,
  DateTime? publishedAt,
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
  descriptionHtml: '<p>$title</p>',
  publishedAt: publishedAt,
);

void main() {
  late AppDatabase database;
  late DateTime now;

  setUp(() {
    database = AppDatabase.inMemory();
    now = DateTime(2026, 10, 6, 9);
  });

  tearDown(() => database.close());

  List<String> ids({JobFilter filter = const JobFilter()}) => [
    for (final job in database.jobs.search(filter: filter)) job.id,
  ];

  group('JobStore', () {
    test('search matches every word across fields, newest first', () {
      database.jobs.saveFetch('remoteok', [
        _job('1', title: 'Rust Engineer', publishedAt: DateTime(2026, 10, 1)),
        _job(
          '2',
          title: 'Senior Rust Engineer',
          publishedAt: DateTime(2026, 10, 5),
        ),
        _job('3', title: 'Designer'),
      ], now);

      expect(ids(), ['remoteok:2', 'remoteok:1', 'remoteok:3']);
      expect(ids(filter: const JobFilter(query: 'rust acme')), hasLength(2));
      expect(ids(filter: const JobFilter(query: 'senior rust')), [
        'remoteok:2',
      ]);
      expect(ids(filter: const JobFilter(query: '100%')), isEmpty);
      expect(
        ids(filter: const JobFilter(excludedSources: {'remoteok'})),
        isEmpty,
      );
    });

    test('filters by region, job type, and salary', () {
      final salary = SalaryRange.of(
        5000,
        null,
        currency: 'USD',
        period: SalaryPeriod.month,
      );
      database.jobs.saveFetch('remoteok', [
        _job(
          '1',
          location: 'Worldwide',
          jobType: 'Penuh waktu',
          salary: salary,
        ),
        _job('2', location: 'USA', jobType: 'Kontrak'),
        _job('3', jobType: 'Penuh waktu, Kontrak'),
      ], now);

      expect(ids(filter: const JobFilter(openToIndonesiaOnly: true)), [
        'remoteok:1',
      ]);
      expect(ids(filter: const JobFilter(jobTypes: {'Kontrak'})), [
        'remoteok:2',
        'remoteok:3',
      ]);
      expect(ids(filter: const JobFilter(withSalaryOnly: true)), [
        'remoteok:1',
      ]);
      expect(
        const JobFilter(
          withSalaryOnly: true,
          jobTypes: {'Kontrak'},
        ).activeCount,
        2,
      );

      final stored = database.jobs.find('remoteok:1')!;
      expect(stored.salaryRange, salary);
      expect(stored.regionFit, RegionFit.open);
    });

    test('list rows omit the description; descriptionOf returns it', () {
      database.jobs.saveFetch('remoteok', [_job('1', title: 'Writer')], now);

      expect(database.jobs.search().single.descriptionHtml, isEmpty);
      expect(database.jobs.descriptionOf('remoteok:1'), '<p>Writer</p>');
      expect(database.jobs.descriptionOf('remoteok:missing'), isEmpty);
    });

    test('saveFetch reports new jobs and prunes old untracked ones', () {
      final first = database.jobs.saveFetch('remoteok', [
        _job('1'),
        _job('2'),
        _job('3'),
      ], now);
      expect(first, ['remoteok:1', 'remoteok:2', 'remoteok:3']);
      database.applications.track(_job('3'), now: now);

      final later = now.add(JobStore.retention + const Duration(days: 1));
      final second = database.jobs.saveFetch('remoteok', [
        _job('2', title: 'Renamed'),
        _job('4'),
      ], later);

      expect(second, ['remoteok:4']);
      // Job 1 is gone; job 3 is no longer listed but stays because it is tracked.
      expect(ids().toSet(), {'remoteok:2', 'remoteok:3', 'remoteok:4'});
      expect(database.jobs.find('remoteok:2')!.title, 'Renamed');
      expect(database.jobs.lastFetchedAt('remoteok'), later);
    });

    test('hidden jobs and blocked companies drop out of the list', () {
      database.jobs.saveFetch('remoteok', [
        _job('1', company: 'Acme'),
        _job('2', company: 'Globex'),
        _job('3', company: 'GLOBEX'),
      ], now);

      database.jobs.setHidden('remoteok:1', true);
      expect(ids(), ['remoteok:2', 'remoteok:3']);
      expect(database.jobs.hiddenCount(), 1);

      database.jobs.blockCompany(' Globex ');
      expect(ids(), isEmpty);
      expect(database.jobs.blockedCompanies(), ['globex']);

      database.jobs.unblockCompany('globex');
      database.jobs.unhideAll();
      expect(ids(), hasLength(3));
    });
  });

  group('ApplicationStore', () {
    test('tracking a job moves it through statuses', () {
      database.jobs.saveFetch('remoteok', [_job('1', title: 'Writer')], now);
      final job = database.jobs.find('remoteok:1')!;
      expect(job.trackedStatus, isNull);

      final saved = database.applications.track(job, now: now);
      expect(saved.status, ApplicationStatus.saved);
      expect(saved.appliedAt, isNull);
      expect(
        database.jobs.find('remoteok:1')!.trackedStatus,
        ApplicationStatus.saved,
      );

      final appliedAt = now.add(const Duration(days: 1));
      final applied = database.applications.setStatus(
        'remoteok:1',
        ApplicationStatus.applied,
        now: appliedAt,
      )!;
      expect(applied.appliedAt, appliedAt);

      // Later moves keep the original applied date.
      final interview = database.applications.setStatus(
        'remoteok:1',
        ApplicationStatus.interview,
        now: appliedAt.add(const Duration(days: 5)),
      )!;
      expect(interview.appliedAt, appliedAt);
      expect(interview.updatedAt, appliedAt.add(const Duration(days: 5)));

      database.applications.save(
        interview.copyWith(notes: 'Call with CTO', interviewAt: () => now),
      );
      final stored = database.applications.find('remoteok:1')!;
      expect(stored.notes, 'Call with CTO');
      expect(stored.interviewAt, now);

      database.applications.delete('remoteok:1');
      expect(database.applications.all(), isEmpty);
      expect(database.jobs.find('remoteok:1')!.trackedStatus, isNull);
    });

    test('manual applications need no fetched job', () {
      final manual = database.applications.addManual(
        title: ' Data Analyst ',
        company: 'Initech',
        url: 'https://www.linkedin.com/jobs/view/1',
        status: ApplicationStatus.applied,
        now: now,
      );

      expect(manual.isManual, isTrue);
      expect(manual.title, 'Data Analyst');
      expect(manual.appliedAt, now);
      expect(database.applications.all().single.jobId, manual.jobId);
      expect(
        database.applications.setStatus(
          'nope',
          ApplicationStatus.offer,
          now: now,
        ),
        isNull,
      );
    });
  });

  group('SourceRegistry', () {
    test('lists enabled built-in and custom sources', () {
      final registry = SourceRegistry(database.sources);
      expect(registry.active(), hasLength(builtInSources.length));

      database.sources.setBuiltInEnabled('remotive', false);
      final gitlab = database.sources.addCustom(
        kind: CustomSourceKind.greenhouse,
        name: 'GitLab',
        value: 'gitlab',
      )!;
      final feed = database.sources.addCustom(
        kind: CustomSourceKind.rss,
        name: 'Example',
        value: 'https://example.com/jobs.rss',
      )!;
      database.sources.setCustomEnabled(feed.id, false);

      expect(
        database.sources.addCustom(
          kind: CustomSourceKind.greenhouse,
          name: 'Duplicate',
          value: 'gitlab',
        ),
        isNull,
      );
      final active = registry.active();
      expect(active.map((source) => source.id), isNot(contains('remotive')));
      expect(active.whereType<GreenhouseSource>().single.board, 'gitlab');
      expect(active.whereType<RssSource>(), isEmpty);
      expect(registry.disabledIds(), {'remotive', feed.sourceId});
      expect(registry.nameOf(gitlab.sourceId), 'GitLab');
      expect(registry.nameOf('remoteok'), 'Remote OK');
      expect(registry.nameOf('manual'), 'Ditambahkan manual');

      database.sources.deleteCustom(gitlab.id);
      expect(registry.nameOf(gitlab.sourceId), 'Sumber yang sudah dihapus');
    });
  });

  group('JobRepository.refresh', () {
    JobRepository repository(MockClientHandler handler) => JobRepository(
      database: database,
      registry: SourceRegistry(
        database.sources,
        builtIn: const [RemoteOkSource(), JobicySource()],
      ),
      client: MockClient(handler),
      clock: () => now,
    );

    test('stores fetched jobs and keeps going when one source fails', () async {
      final result = await repository((request) async {
        if (request.url.host == 'remoteok.com') {
          expect(request.headers['User-Agent'], isNotEmpty);
          return http.Response(_remoteOkBody, 200);
        }
        return http.Response('Service Unavailable', 503);
      }).refresh(manual: false);

      expect(result.fetched, {'Remote OK': 2});
      expect(result.errors, {'Jobicy': 'HTTP 503'});
      expect(result.newJobIds, ['remoteok:1', 'remoteok:2']);
      expect(database.jobs.search().map((job) => job.title), [
        'Rust Engineer',
        'Product Designer',
      ]);
      expect(database.jobs.lastFetchedAt('remoteok'), now);
      // A failed source is not marked as fetched, so it is retried next time.
      expect(database.jobs.lastFetchedAt('jobicy'), isNull);
    });

    test('skips sources that were fetched recently', () async {
      final requests = <String>[];
      final repo = repository((request) async {
        requests.add(request.url.host);
        return switch (request.url.host) {
          'remoteok.com' => http.Response(_remoteOkBody, 200),
          'api.frankfurter.dev' => http.Response(_ratesBody, 200),
          _ => http.Response('{"jobs": []}', 200),
        };
      });

      await repo.refresh(manual: true);
      expect(requests, hasLength(3));
      expect(repo.exchangeRates()!.rates['IDR'], 18000);

      now = now.add(const Duration(minutes: 10));
      final soon = await repo.refresh(manual: true);
      expect(requests, hasLength(3));
      expect(soon.skipped, ['Remote OK', 'Jobicy']);
      expect(soon.newJobIds, isEmpty);

      // Past the sources' own minimum, a manual refresh fetches again while
      // an automatic one still waits. Rates are fetched once a day.
      now = now.add(const Duration(hours: 2));
      await repo.refresh(manual: false);
      expect(requests, hasLength(3));
      await repo.refresh(manual: true);
      expect(requests, hasLength(5));
    });

    test('reports an unreadable body without touching stored jobs', () async {
      database.jobs.saveFetch('remoteok', [
        _job('1'),
      ], now.subtract(const Duration(days: 1)));

      final repo = repository(
        (request) async => http.Response('<html>blocked</html>', 200),
      );
      final result = await repo.refresh(manual: true);

      expect(result.errors.keys, containsAll(['Remote OK', 'Jobicy']));
      expect(result.errors['Remote OK'], 'format data tidak dikenali');
      expect(database.jobs.search().single.id, 'remoteok:1');
      expect(repo.exchangeRates(), isNull);
    });

    test('a switched-off source is not fetched', () async {
      database.sources.setBuiltInEnabled('jobicy', false);
      final hosts = <String>[];

      await repository((request) async {
        hosts.add(request.url.host);
        return http.Response(_remoteOkBody, 200);
      }).refresh(manual: true);

      expect(hosts, isNot(contains('jobicy.com')));
    });
  });

  test('opening an older database upgrades it and keeps its jobs', () {
    // The schema as first released, with one job stored.
    final old = AppDatabase.inMemory();
    old.sql.execute('''
      DROP TABLE cvs; DROP TABLE reviews; DROP TABLE answers; DROP TABLE ai_spend;
      DROP TABLE alerts; DROP TABLE applications; DROP TABLE blocked_companies;
      DROP TABLE source_settings; DROP TABLE custom_sources; DROP TABLE settings;
      DROP TABLE jobs; DROP TABLE source_state;
      CREATE TABLE jobs (
        id TEXT PRIMARY KEY, source_id TEXT NOT NULL, title TEXT NOT NULL,
        company TEXT NOT NULL, url TEXT NOT NULL, location TEXT NOT NULL,
        category TEXT NOT NULL, tags TEXT NOT NULL, job_type TEXT NOT NULL,
        salary TEXT NOT NULL, description_html TEXT NOT NULL,
        published_at INTEGER, first_seen_at INTEGER NOT NULL,
        last_seen_at INTEGER NOT NULL
      );
      CREATE TABLE source_state (
        source_id TEXT PRIMARY KEY, last_fetched_at INTEGER NOT NULL
      );
      INSERT INTO jobs VALUES ('remoteok:1', 'remoteok', 'Writer', 'Acme',
        'https://remoteok.com/1', 'Worldwide', '', '[]', '', '', '<p>x</p>',
        NULL, 1, 1);
      INSERT INTO source_state VALUES ('remoteok', 1);
      PRAGMA user_version = 1;
    ''');
    final path =
        '${Directory.systemTemp.createTempSync('jobs_db').path}/jobs.db';
    old.sql.execute('VACUUM INTO ?', [path]);
    old.close();

    final upgraded = AppDatabase.open(path);
    addTearDown(upgraded.close);

    final job = upgraded.jobs.search(
      filter: const JobFilter(openToIndonesiaOnly: true),
    );
    expect(job.single.title, 'Writer');
    // Sources are fetched again so the new salary columns get filled.
    expect(upgraded.jobs.lastFetchedAt('remoteok'), isNull);
    expect(upgraded.applications.all(), isEmpty);
  });
}
